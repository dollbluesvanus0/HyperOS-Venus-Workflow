#!/usr/bin/env bash
set -euo pipefail
DONOR_DIR="$1"; STOCK_DIR="$2"; OUT_DIR="$3"
mkdir -p "$OUT_DIR"/{donor,stock,logs}

echo "📦 Extracting ZIPs..."
unzip -o "$DONOR_DIR.zip" -d "$OUT_DIR/donor/raw/" > /dev/null
unzip -o "$STOCK_DIR.zip" -d "$OUT_DIR/stock/raw/" > /dev/null

extract_payload() {
  local src="$1" dst="$2"
  if [ -f "$src/payload.bin" ]; then
    echo "📥 Extracting payload.bin..."
    payload-dumper-go -o "$dst" "$src/payload.bin"
  else
    echo "⚠️  No payload.bin found in $src"
    return 0
  fi
}

extract_super() {
  local src="$1" dst="$2"
  if [ -f "$src/super.img" ]; then
    echo "📥 Unpacking super.img..."
    lpunpack "$src/super.img" "$dst"
    rm -f "$src/super.img"
  fi
}

extract_payload "$OUT_DIR/donor/raw" "$OUT_DIR/donor/img" || extract_super "$OUT_DIR/donor/raw" "$OUT_DIR/donor/img"
extract_payload "$OUT_DIR/stock/raw" "$OUT_DIR/stock/img" || extract_super "$OUT_DIR/stock/raw" "$OUT_DIR/stock/img"

echo "🗜️ Unpacking logical images..."
for part in system_ext product vendor; do
  for root in donor stock; do
    img="$OUT_DIR/$root/img/${part}.img"
    dir="$OUT_DIR/$root/${part}"
    [ -f "$img" ] || continue
    mkdir -p "$dir"
    if file "$img" | grep -q "EROFS"; then
      dump.erofs -i "$img" -o "$dir"
    else
      simg2img "$img" "$dir/${part}.raw"
      sudo mount -o loop,ro "$dir/${part}.raw" "$dir"
    fi
    echo "✅ Unpacked $root/$part"
  done
done
echo "🔍 Extraction complete."