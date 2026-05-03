echo "🗜️ Unpacking with AIK..."
for part in system_ext product vendor; do
  for root in donor stock; do
    img="$OUT_DIR/$root/img/${part}.img"
    dir="$OUT_DIR/$root/${part}"
    [ -f "$img" ] || continue
    mkdir -p "$dir"
    
    # AIK автоматически работает с ext4, erofs, sparse
    cd /tmp/kitchen
    cp "$img" img/$part.img
    ./unpackimg.sh img/$part.img > /dev/null 2>&1
    cp -r split_img/* "$dir/" 2>/dev/null || true
    cp -r ramdisk/* "$dir/" 2>/dev/null || true
    # Для системных разделов AIK кладёт файлы в split_img/ или image/
    if [ -d "split_img/$part.img_dir" ]; then
      cp -r split_img/$part.img_dir/* "$dir/"
    fi
    cd -
    echo "✅ Unpacked $root/$part via AIK"
  done
done
