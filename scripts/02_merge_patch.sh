#!/usr/bin/env bash
set -euo pipefail
WORK="$1"; EXTRA_PROPS="$2"
DONOR="$WORK/donor"; STOCK="$WORK/stock"

# === Твой код мержа (из первого сообщения) ===
# 1. device_features & displayconfig
rsync -a --delete "$STOCK/product/etc/device_features/" "$DONOR/product/etc/device_features/"
rsync -a --delete "$STOCK/product/etc/displayconfig/" "$DONOR/product/etc/displayconfig/"

# 2. MiuiBiometric
biometric_src=$(find "$STOCK/product/app" -maxdepth 1 -type d -name "*[Bb]iometric*" | head -1)
[ -n "$biometric_src" ] && cp -r "$biometric_src" "$DONOR/product/app/"

# 3. pangu/system -> /product
rsync -a --ignore-existing "$STOCK/product/pangu/system/" "$DONOR/product/"

# 4. Overlays
for apk in AospFrameworkResOverlay DevicesAndroidOverlay DevicesOverlay MiuiFrameworkResOverlay SettingsRroDeviceHideStatusBarOverlay; do
  src=$(find "$STOCK/product/overlay" -name "${apk}.apk" | head -1)
  [ -n "$src" ] && cp "$src" "$DONOR/product/overlay/"
done

# 5. vendor build.prop fix
vendor_prop="$DONOR/vendor/build.prop"
if [ -f "$vendor_prop" ]; then
  sed -i 's/^ro.control_privapp_permissions=.*/ro.control_privapp_permissions=disable/' "$vendor_prop"
  grep -q "^ro.control_privapp_permissions=" "$vendor_prop" || echo "ro.control_privapp_permissions=disable" >> "$vendor_prop"
fi

# 6. build.prop правка (безопасная)
prop_file="$DONOR/product/etc/build.prop"
python3 - <<PYEOF
import re
props = {"persist.miui.density_v2": "560", "ro.sf.lcd_density": "560"}
extra = """$EXTRA_PROPS"""
for line in extra.strip().splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        props[k.strip()] = v.strip()
with open("$prop_file", "r+") as f:
    content = f.read()
    for k, v in props.items():
        pattern = re.compile(rf"^{re.escape(k)}=.*$", re.MULTILINE)
        if pattern.search(content):
            content = pattern.sub(f"{k}={v}", content)
        else:
            content += f"\n{k}={v}"
    f.seek(0); f.write(content); f.truncate()
PYEOF

# 7. Удаление мусора (твой список)
BLOAT=(
  "product/app/AnalyticsCore" "product/app/CarWith" "product/app/CatchLog"
  "product/app/MIUIGuardProvider" "product/app/MIUIsecurityinputmethod"
  "product/app/MIUIsupermarket" "product/app/Music" "product/app/SogouIME"
  "product/app/System" "product/app/Updater" "product/app/UPTsmService"
  "product/app/VoiceAssistAndroidT" "product/app/VoiceTrigger"
  "product/data-app/BaiduIME" "product/data-app/IFlytekIME" "product/data-app/MiGalleryLockScreen"
  "product/data-app/MIUICompass" "product/data-app/MIService" "product/data-app/MiuiEmail"
  "product/data-app/MiuiHuanji" "product/data-app/MiuiMidrive" "product/data-app/MiuiVirtualSim"
  "product/data-app/MiuiXiaoAiSpeechEngine" "product/data-app/OS2VipAccount" "product/data-app/SmartHome"
  "product/data-app/ThirdAppAssistant" "product/data-app/XMRemoteController"
  "product/priv-app/LinkToWindows" "product/priv-app/MIUIbrowser"
)
for b in "${BLOAT[@]}"; do
  target="$DONOR/$b"
  [ -e "$target" ] && rm -rf "$target"
done

echo "🧹 Мерж завершён."
