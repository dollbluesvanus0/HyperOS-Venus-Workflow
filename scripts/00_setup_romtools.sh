#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "📥 Клонирование RomTools..."
git clone --depth 1 https://github.com/Danda420/RomTools.git RomTools
cd RomTools

echo "🔧 Установка зависимостей (без интерактива)..."
# RomTools использует меню, но мы вызовем установку напрямую
# Определяем дистрибутив и ставим пакеты как делает RomTools
if [ -f /etc/debian_version ]; then
  sudo apt-get update
  sudo apt-get install -y \
    erofs-utils e2fsprogs android-sdk-libsparse-utils \
    p7zip-full python3 curl jq unzip wget liblz4-tool file \
    zstd lzip lzop xz-utils
elif [ -f /etc/arch-release ]; then
  sudo pacman -Syu --noconfirm \
    erofs-utils e2fsprogs android-tools p7zip python curl jq \
    wget zstd lzip lzop xz
fi

# Проверяем, что бинарники на месте
BIN_DIR="tool/bin"
[ -f "$BIN_DIR/lpunpack" ] || echo "⚠️ lpunpack not found, will use system"
[ -f "$BIN_DIR/lpmake" ] || echo "⚠️ lpmake not found, will use system"
[ -f "$BIN_DIR/mkfs.erofs" ] || echo "⚠️ mkfs.erofs not found, will use system"

# Добавляем в PATH для последующих шагов
echo "$GITHUB_WORKSPACE/RomTools/tool/bin" >> $GITHUB_PATH
echo "$GITHUB_WORKSPACE/RomTools/tool" >> $GITHUB_PATH

echo "✅ RomTools готов. Бинарники: $(ls tool/bin | wc -l) шт."
