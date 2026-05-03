# Автоматическое портирование HyperOS (Qualcomm)

Этот репозиторий содержит скрипты для автоматизации портирования HyperOS на устройства Qualcomm с использованием GitHub Actions.

## 📋 Что делает скрипт

1. **Распаковывает** архивы донора (HyperOS) и стока.
2. **Извлекает** образы из `payload.bin` (если есть) или работает с `.img`.
3. **Конвертирует** sparse images в raw формат.
4. **Извлекает файлы** из образов без монтирования (через `debugfs`).
5. **Объединяет разделы**:
   - Из **донора**: `system`, `system_ext`, `product`, `mi_ext`
   - Из **стока**: `vendor`, `odm`
6. **Выполняет правки**:
   - Копирует `MiuiCamera` из стока (`vendor`) в донор (`product/priv-app`)
7. **Собирает** финальный `super.img` размером 8.5 ГБ.

## 🚀 Использование

### Вариант 1: Локально (Linux)

1. Установите зависимости:
```bash
sudo apt-get update
sudo apt-get install -y android-sdk-build-tools simg2img img2simg e2fsprogs debugfs zip unzip curl wget android-sdk-ext4-utils
```

2. Скачайте утилиту для распаковки payload.bin:
```bash
wget https://github.com/ssut/payload-dumper-go/releases/latest/download/payload-dumper-go_linux_amd64 -O payload-dumper-go
chmod +x payload-dumper-go
sudo mv payload-dumper-go /usr/local/bin/
```

3. Подготовьте файлы:
   - Положите `donor.zip` (HyperOS) и `stock.zip` (Stock ROM) в одну папку со скриптом.

4. Запустите:
```bash
chmod +x port_hyperos.sh
./port_hyperos.sh
```

5. Результат будет в папке `output/super.img`.

---

### Вариант 2: GitHub Actions (Автоматически)

1. **Загрузите** этот репозиторий на свой GitHub.

2. **Подготовьте ROM'ы**:
   - Либо загрузите файлы `donor.zip` и `stock.zip` в папку `roms/` вашего репозитория.
   - Либо используйте **Workflow Dispatch** для указания прямых ссылок на скачивание.

3. **Запустите workflow**:
   - Перейдите во вкладку **Actions**.
   - Выберите **HyperOS Porting Automation**.
   - Нажмите **Run workflow**.
   - Вставьте ссылки на donor и stock ROM (если не загрузили файлы заранее).

4. **Скачайте результат**:
   - После завершения сборки скачайте артефакт `hyperos-port-result`.
   - Файл `super.img` будет доступен в течение 7 дней.

---

## ⚙️ Конфигурация

В начале скрипта `port_hyperos.sh` можно изменить параметры:

```bash
DONOR_ZIP="donor.zip"       # Имя файла с HyperOS
STOCK_ZIP="stock.zip"       # Имя файла со Стоком
SUPER_SIZE=8589934592       # Размер super.img (8.5 GB)
```

## 🔧 Требования

- **ОС**: Linux (Ubuntu 20.04+ рекомендуется)
- **Свободное место**: минимум 25 ГБ
- **Зависимости**:
  - `android-sdk-build-tools`
  - `simg2img` / `img2simg`
  - `e2fsprogs` / `debugfs`
  - `make_ext4fs`
  - `payload-dumper-go`
  - `lpmake`

## ⚠️ Важные замечания

1. **GitHub Actions ограничения**:
   - Публичные раннеры могут не поддерживать монтирование образов.
   - Скрипт использует `debugfs` для извлечения файлов без монтирования.
   - Для больших ROM'ов может потребоваться self-hosted runner.

2. **Совместимость**:
   - Скрипт тестировался на устройствах Qualcomm с динамическими разделами.
   - Для MediaTek требуется модификация (другой формат образов).

3. **MiuiCamera**:
   - Скрипт автоматически копирует камеру из стока.
   - Если камера не найдена, сборка продолжится без замены (будет предупреждение).

4. **Boot Image**:
   - Скрипт **не патчит** `boot.img`.
   - Вам нужно самостоятельно прошить совместимый boot/image с вашего стока.

## 🛠️ Расширение функционала

Для добавления новых правок отредактируйте функцию `merge_roms()` в скрипте:

```bash
# Пример: копирование конфигов WiFi
cp -rf "$S_VEND/etc/wifi/" "$D_PROD/etc/wifi/"

# Пример: удаление конфликтующих приложений
rm -rf "$D_PROD/app/BloatwareApp"
```

## 📄 Лицензия

Используйте на свой страх и риск. Автор не несет ответственности за кирпичи устройств.

## 🤝 Contributing

Если вы нашли ошибку или хотите улучшить скрипт — создавайте Pull Request!
