#!/usr/bin/env bash
set -euo pipefail
DONOR_DIR="$1"; STOCK_DIR="$2"; OUT_DIR="$3"
mkdir -p "$OUT_DIR"/{donor,stock,logs}

echo "📦 Извлечение архивов..."
unzip -o "$DONOR_DIR.zip" -d "$OUT_DIR/donor/raw/" > /dev/null
unzip -o "$STOCK_DIR.zip" -d "$OUT_DIR/stock/raw/" > /dev/null

extract_payload() {
  local src="$1" dst="$2"
  if [ -f "$src/payload.bin" ]; then
    echo "📥 Распаковка payload.bin..."
    payload-dumper-go -o "$dst" "$src/payload.bin"
  else
    echo "⚠️ payload.bin не найден в $src"
  fi
}

extract_super() {
  local src="$1" dst="$2"
  if [ -f "$src/super.img" ]; then
    echo "📥 Распаковка super.img..."
    mkdir -p "$dst"
    lpunpack "$src/super.img" "$dst"
    rm -f "$src/super.img"
  fi
}

extract_payload "$OUT_DIR/donor/raw" "$OUT_DIR/donor/img"
extract_super "$OUT_DIR/donor/raw" "$OUT_DIR/donor/img"

extract_payload "$OUT_DIR/stock/raw" "$OUT_DIR/stock/img"
extract_super "$OUT_DIR/stock/raw" "$OUT_DIR/stock/img"

echo "🗜️ Распаковка логических разделов..."
for part in system_ext product vendor; do
  for root in donor stock; do
    img="$OUT_DIR/$root/img/${part}.img"
    dir="$OUT_DIR/$root/${part}"
    [ -f "$img" ] || continue
    mkdir -p "$dir"
    
    if file "$img" | grep -qi "EROFS"; then
      dump.erofs -i "$img" -o "$dir"
    else
      simg2img "$img" "$dir/${part}.raw"
      # 7z извлекает ext4 без монтирования и root
      7z x "$dir/${part}.raw" -o"$dir" -y > /dev/null
      rm -f "$dir/${part}.raw"
    fi
    echo "✅ Распаковано: $root/$part"
  done
done
echo "🟢 Распаковка завершена."
