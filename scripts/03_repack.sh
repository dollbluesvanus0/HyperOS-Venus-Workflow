#!/usr/bin/env bash
set -euo pipefail
WORK="$1"; OUT="$2"
mkdir -p "$OUT"

echo "📦 Repacking to erofs..."
for part in system_ext product; do
  dir="$WORK/donor/$part"
  img="$OUT/${part}.img"
  [ -d "$dir" ] || continue
  
  # Отмонтируем если было смонтировано
  sudo umount -l "$dir" 2>/dev/null || true
  rm -f "$dir/${part}.raw"
  
  # Xiaomi использует lz4hc, legacy-compress для совместимости
  mkfs.erofs -T $(date +%s) -zlz4hc,12 -b 4096 -E legacy-compress "$img" "$dir"
  echo "✅ ${part}.img created"
done

# Vendor оставляем как есть (стоковый, без правок)
cp "$WORK/stock/vendor/vendor.img" "$OUT/vendor.img" 2>/dev/null || true

echo "📏 Calculating partition sizes..."
calc_size() {
  local dir="$1"
  local used=$(du -sb "$dir" 2>/dev/null | cut -f1)
  echo $(( used * 115 / 100 )) # +15% padding
}

SIZE_SE=$(calc_size "$WORK/donor/system_ext")
SIZE_PR=$(calc_size "$WORK/donor/product")
SIZE_VN=$(stat -c%s "$OUT/vendor.img" 2>/dev/null || echo 1073741824)

TOTAL=$(( SIZE_SE + SIZE_PR + SIZE_VN ))
LIMIT=8912896000 # 8.5 GB

if [ $TOTAL -gt $LIMIT ]; then
  echo "⚠️  Total size $TOTAL exceeds 8.5GB limit. Scaling down..."
  SCALE=$(( LIMIT * 90 / 100 / TOTAL ))
  SIZE_SE=$(( SIZE_SE * SCALE / 100 ))
  SIZE_PR=$(( SIZE_PR * SCALE / 100 ))
fi

echo "🔧 Building super.img (limit: 8.5GB)..."
lpmake \
  --metadata-size 65536 \
  --super-name super \
  --metadata-slots 2 \
  --device super:$LIMIT \
  --group main:$LIMIT \
  --partition system_ext:readonly:$SIZE_SE:main \
  --image system_ext="$OUT/system_ext.img" \
  --partition product:readonly:$SIZE_PR:main \
  --image product="$OUT/product.img" \
  --partition vendor:readonly:$SIZE_VN:main \
  --image vendor="$OUT/vendor.img" \
  --output "$OUT/super.img"

echo "✅ super.img created successfully"
cp "$OUT/super.img" "$OUT/super.img" # Артефакт
echo "📦 Repack complete."