#!/usr/bin/env bash
set -euo pipefail
DONOR_DIR="$1"; STOCK_DIR="$2"; OUT_DIR="$3"
ROMTOOLS_BIN="${ROMTOOLS_BIN:-$(dirname "$0")/../RomTools/tool/bin}"
ROMTOOLS_FUNC="${ROMTOOLS_FUNC:-$(dirname "$0")/../RomTools/tool/functions}"

mkdir -p "$OUT_DIR"/{donor,stock,logs}

echo "📦 Распаковка архивов..."
unzip -o "$DONOR_DIR.zip" -d "$OUT_DIR/donor/raw/" > /dev/null
unzip -o "$STOCK_DIR.zip" -d "$OUT_DIR/stock/raw/" > /dev/null

# Функция распаковки payload.bin через RomTools-бинарник
extract_payload() {
  local src="$1" dst="$2"
  if [ -f "$src/payload.bin" ]; then
    echo "📥 payload.bin → $dst"
    # RomTools использует payload-dumper-go из tool/bin/
    "$ROMTOOLS_BIN/payload-dumper-go" -o "$dst" "$src/payload.bin" 2>/dev/null || \
    payload-dumper-go -o "$dst" "$src/payload.bin"
  fi
}

# Распаковка super.img через lpunpack
extract_super() {
  local src="$1" dst="$2"
  if [ -f "$src/super.img" ]; then
    echo "📥 super.img → $dst"
    mkdir -p "$dst"
    "$ROMTOOLS_BIN/lpunpack" "$src/super.img" "$dst" 2>/dev/null || \
    lpunpack "$src/super.img" "$dst"
    rm -f "$src/super.img"
  fi
}

# Обрабатываем донор и сток
for root in donor stock; do
  RAW="$OUT_DIR/$root/raw"
  IMG="$OUT_DIR/$root/img"
  mkdir -p "$IMG"
  extract_payload "$RAW" "$IMG"
  extract_super "$RAW" "$IMG"
done

echo "🗜️ Распаковка логических разделов..."
for part in system_ext product vendor; do
  for root in donor stock; do
    img="$OUT_DIR/$root/img/${part}.img"
    dir="$OUT_DIR/$root/${part}"
    [ -f "$img" ] || continue
    mkdir -p "$dir"
    
    # Определяем тип образа и распаковываем
    if file "$img" | grep -qi "EROFS"; then
      echo "  📄 $root/$part: EROFS"
      "$ROMTOOLS_BIN/dump.erofs" -i "$img" -o "$dir" 2>/dev/null || \
      dump.erofs -i "$img" -o "$dir"
    else
      echo "  📄 $root/$part: EXT4/sparse"
      "$ROMTOOLS_BIN/simg2img" "$img" "$dir/${part}.raw" 2>/dev/null || \
      simg2img "$img" "$dir/${part}.raw"
      # 7z извлекает ext4 без монтирования
      7z x "$dir/${part}.raw" -o"$dir" -y > /dev/null
      rm -f "$dir/${part}.raw"
    fi
    echo "  ✅ $root/$part"
  done
done
echo "🟢 Распаковка завершена."
