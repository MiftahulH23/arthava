#!/bin/sh
# Unduh Plus Jakarta Sans (bobot 400–800, file yang sama dengan google_fonts)
# ke .dart_tool/screenshot_fonts untuk test screenshot (test/screenshots/).
# Jalankan sekali per clone:  sh tool/screenshots/fetch_fonts.sh
set -e
dir=.dart_tool/screenshot_fonts
mkdir -p "$dir"
for pair in \
  400:80501e2c94323d8b8d48b29bc73aa042539f0a6e62c3afe318980de7b7b19267 \
  500:d69a8aa421db9df3e7d624119c9ee103d342e1dacff8bb29e36eebd379fdb7de \
  600:ba0432c50b99a58d041dc19291e1ff0a3c0e17fa254fe58510a96248426718d6 \
  700:dbf8d18a2d1c11f9b68005f52aaefe3974273175b1048047d662a13858c1e9e6 \
  800:16b18d8f75d223acf2959d157e76addcbf64e153a7262b05aefc2f4c6f47ebca; do
  w=${pair%%:*}; h=${pair#*:}
  curl -sSf -o "$dir/PlusJakartaSans_$w.ttf" "https://fonts.gstatic.com/s/a/$h.ttf"
done
echo "Font tersimpan di $dir. Jalankan: flutter test test/screenshots  (PNG di build/screenshots/)"
