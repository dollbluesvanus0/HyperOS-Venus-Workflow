#!/usr/bin/env bash
set -euo pipefail

# HyperOS Auto-Port Script (адаптировано для GitHub Actions)
# Референс: https://github.com/StabilityBrickOS/HyperOS-Auto-Port-Plugin

PROJECT_DIR="$1"
DENSITY="${2:-560}"
EXTRA_PROPS="$3"

DONOR="$PROJECT_DIR/donor"
STOCK="$PROJECT_DIR/stock"

echo "=========================================="
echo "[INFO] HyperOS Auto-Port Script"
echo "=========================================="
echo "[INFO] Stock project: $STOCK"
echo "[INFO] Port project: $DONOR"
echo ""

# Проверка существования директорий
if [ ! -d "$STOCK" ]; then
    echo "[ERROR] Stock project not found: $STOCK"
    exit 1
fi

if [ ! -d "$DONOR" ]; then
    echo "[ERROR] Port project not found: $DONOR"
    exit 1
fi

# STEP 1: Копирование mi_ext build.prop в product
echo "[STEP 1] Copying mi_ext build.prop to product..."
MI_EXT_BUILD_PROP="$DONOR/mi_ext/etc/build.prop"
PRODUCT_BUILD_PROP="$DONOR/product/etc/build.prop"

if [ -f "$MI_EXT_BUILD_PROP" ]; then
    if [ -f "$PRODUCT_BUILD_PROP" ]; then
        echo "[INFO] Appending mi_ext/etc/build.prop to product/etc/build.prop"
        {
            echo ""
            echo "# =========================================="
            echo "# imported from mi_ext"
            echo "# =========================================="
            cat "$MI_EXT_BUILD_PROP"
        } >> "$PRODUCT_BUILD_PROP"
        echo "[OK] Build.prop merged successfully"
    else
        echo "[WARNING] $PRODUCT_BUILD_PROP not found, skipping..."
    fi
else
    echo "[WARNING] $MI_EXT_BUILD_PROP not found, skipping..."
fi
echo ""

# STEP 2: Копирование папок из mi_ext/product/ в product/
echo "[STEP 2] Copying folders from mi_ext/product/ to product/..."
MI_EXT_PRODUCT="$DONOR/mi_ext/product"
PRODUCT_DIR="$DONOR/product"

if [ -d "$MI_EXT_PRODUCT" ]; then
    cd "$MI_EXT_PRODUCT" || exit 1
    for item in *; do
        if [ -d "$item" ]; then
            echo "[INFO] Copying folder: $item"
            cp -rf "$item" "$PRODUCT_DIR/"
        fi
    done
    echo "[OK] All folders copied from mi_ext/product/"
else
    echo "[WARNING] $MI_EXT_PRODUCT not found, skipping..."
fi
echo ""

# STEP 3: Перемещение папок из product/pangu/system/ в system/system/
echo "[STEP 3] Moving folders from product/pangu/system/ to system/system/..."
PANGU_SYSTEM="$DONOR/product/pangu/system"
SYSTEM_SYSTEM="$DONOR/system/system"

if [ -d "$PANGU_SYSTEM" ]; then
    if [ -d "$SYSTEM_SYSTEM" ]; then
        cd "$PANGU_SYSTEM" || exit 1
        for item in *; do
            if [ -d "$item" ]; then
                echo "[INFO] Moving folder: $item"
                cp -rf "$item" "$SYSTEM_SYSTEM/"
                rm -rf "$item"
            fi
        done
        echo "[OK] All folders moved from product/pangu/system/"
    else
        echo "[WARNING] $SYSTEM_SYSTEM not found, skipping..."
    fi
else
    echo "[WARNING] $PANGU_SYSTEM not found, skipping..."
fi
echo ""

# STEP 4: Копирование device_features из stock в port
echo "[STEP 4] Copying device_features from stock to port..."
STOK_DEVICE_FEATURES="$STOCK/product/etc/device_features"
PORT_DEVICE_FEATURES="$DONOR/product/etc/device_features"

if [ -d "$STOK_DEVICE_FEATURES" ]; then
    if [ ! -d "$PORT_DEVICE_FEATURES" ]; then
        mkdir -p "$PORT_DEVICE_FEATURES"
    fi
    cd "$STOK_DEVICE_FEATURES" || exit 1
    for file in *; do
        if [ -f "$file" ]; then
            echo "[INFO] Copying: $file"
            cp -f "$file" "$PORT_DEVICE_FEATURES/"
        fi
    done
    echo "[OK] Device features copied"
else
    echo "[WARNING] $STOK_DEVICE_FEATURES not found, skipping..."
fi
echo ""

# STEP 5: Переименование display_id XML для соответствия stock
echo "[STEP 5] Renaming display_id XML to match stock..."
STOK_DISPLAYCONFIG="$STOCK/product/etc/displayconfig"
PORT_DISPLAYCONFIG="$DONOR/product/etc/displayconfig"

if [ -d "$STOK_DISPLAYCONFIG" ] && [ -d "$PORT_DISPLAYCONFIG" ]; then
    STOK_DISPLAY_FILE=$(cd "$STOK_DISPLAYCONFIG" && ls display_id_*.xml 2>/dev/null | head -n 1)
    
    if [ -n "$STOK_DISPLAY_FILE" ]; then
        echo "[INFO] Stock display file: $STOK_DISPLAY_FILE"
        PORT_DISPLAY_FILE=$(cd "$PORT_DISPLAYCONFIG" && ls display_id_*.xml 2>/dev/null | head -n 1)
        
        if [ -n "$PORT_DISPLAY_FILE" ]; then
            if [ "$STOK_DISPLAY_FILE" != "$PORT_DISPLAY_FILE" ]; then
                echo "[INFO] Renaming $PORT_DISPLAY_FILE to $STOK_DISPLAY_FILE"
                mv "$PORT_DISPLAYCONFIG/$PORT_DISPLAY_FILE" "$PORT_DISPLAYCONFIG/$STOK_DISPLAY_FILE"
                echo "[OK] Display config renamed"
            else
                echo "[INFO] Display config already has correct name"
            fi
        else
            echo "[WARNING] No display_id file found in port"
        fi
    else
        echo "[WARNING] No display_id file found in stock"
    fi
else
    echo "[WARNING] Display config directories not found, skipping..."
fi
echo ""

# STEP 6: Копирование отсутствующих VNDK apex файлов
echo "[STEP 6] Copying missing VNDK apex files..."
STOK_VNDK_DIR="$STOCK/system_ext/apex"
PORT_VNDK_DIR="$DONOR/system_ext/apex"

if [ -d "$STOK_VNDK_DIR" ]; then
    if [ ! -d "$PORT_VNDK_DIR" ]; then
        mkdir -p "$PORT_VNDK_DIR"
    fi
    cd "$STOK_VNDK_DIR" || exit 1
    for file in com.android.vndk.v*.apex; do
        if [ -f "$file" ]; then
            if [ ! -f "$PORT_VNDK_DIR/$file" ]; then
                echo "[INFO] Copying missing VNDK: $file"
                cp -f "$file" "$PORT_VNDK_DIR/"
            else
                echo "[INFO] Already exists, skipping: $file"
            fi
        fi
    done
    echo "[OK] VNDK apex files processed"
else
    echo "[WARNING] $STOK_VNDK_DIR not found, skipping..."
fi
echo ""

# STEP 7: Обновление build.prop с density и extra props
echo "[STEP 7] Updating build.prop with density and extra props..."
prop_file="$DONOR/product/etc/build.prop"
python3 - <<PYEOF
import re, sys
props = {"persist.miui.density_v2": "$DENSITY", "ro.sf.lcd_density": "$DENSITY"}
extra = """$EXTRA_PROPS"""
for line in extra.strip().splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        props[k.strip()] = v.strip()
with open("$prop_file", "r+") as f:
    content = f.read()
    for k, v in props.items():
        pattern = re.compile(rf"^{re.escape(k)}=.*$", re.MULTILINE)
        content = pattern.sub(f"{k}={v}", content) if pattern.search(content) else content + f"\n{k}={v}"
    f.seek(0); f.write(content); f.truncate()
PYEOF
echo "[OK] Build.prop updated"
echo ""

# STEP 8: Удаление bloatware
echo "[STEP 8] Removing bloatware..."
BLOAT=(
  product/app/AnalyticsCore product/app/CarWith product/app/CatchLog
  product/app/MIUIGuardProvider product/app/MIUIsecurityinputmethod
  product/app/MIUIsupermarket product/app/Music product/app/SogouIME
  product/app/System product/app/Updater product/app/UPTsmService
  product/app/VoiceAssistAndroidT product/app/VoiceTrigger
  product/data-app/BaiduIME product/data-app/IFlytekIME product/data-app/MiGalleryLockScreen
  product/data-app/MIUICompass product/data-app/MIService product/data-app/MiuiEmail
  product/data-app/MiuiHuanji product/data-app/MiuiMidrive product/data-app/MiuiVirtualSim
  product/data-app/MiuiXiaoAiSpeechEngine product/data-app/OS2VipAccount product/data-app/SmartHome
  product/data-app/ThirdAppAssistant product/data-app/XMRemoteController
  product/priv-app/LinkToWindows product/priv-app/MIUIbrowser
)
for b in "${BLOAT[@]}"; do
  target="$DONOR/$b"
  [ -e "$target" ] && rm -rf "$target"
done
echo "[OK] Bloatware removed"
echo ""

# STEP 9: Фикс vendor/build.prop
echo "[STEP 9] Fixing vendor/build.prop..."
vendor_prop="$DONOR/vendor/build.prop"
if [ -f "$vendor_prop" ]; then
  sed -i 's/^ro.control_privapp_permissions=.*/ro.control_privapp_permissions=disable/' "$vendor_prop"
  grep -q "^ro.control_privapp_permissions=" "$vendor_prop" || echo "ro.control_privapp_permissions=disable" >> "$vendor_prop"
  echo "[OK] Vendor build.prop fixed"
else
  echo "[WARNING] $vendor_prop not found, skipping..."
fi
echo ""

echo "=========================================="
echo "[OK] HyperOS Auto-Port completed!"
echo "=========================================="
