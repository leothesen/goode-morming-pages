#!/bin/bash
# Renders Icon/icon.svg into the AppIcon asset catalog.
#
# Run from the repo root after editing the SVG:
#   ./Icon/render.sh
#
# Uses whatever headless Chromium is on the machine. macOS ships no SVG
# rasteriser, and re-encoding the PNGs by hand truncates them silently.
set -euo pipefail

SVG="Icon/icon.svg"
OUT="GoodeMormingPages/Assets.xcassets/AppIcon.appiconset"

CHROME=$(ls -d "$HOME"/Library/Caches/ms-playwright/chromium_headless_shell-*/chrome-mac/headless_shell 2>/dev/null | tail -1 || true)
if [ -z "$CHROME" ]; then
  CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
fi
if [ ! -x "$CHROME" ]; then
  echo "no headless chromium found" >&2
  exit 1
fi

mkdir -p "$OUT"
TMP=$(mktemp -d)

for SIZE in 16 32 64 128 256 512 1024; do
  cat > "$TMP/page.html" <<HTML
<!doctype html><meta charset="utf-8">
<style>
  html,body{margin:0;padding:0;background:transparent}
  img{width:${SIZE}px;height:${SIZE}px;display:block}
</style>
<img src="icon.svg">
HTML
  cp "$SVG" "$TMP/icon.svg"

  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --default-background-color=00000000 \
    --force-device-scale-factor=1 \
    --window-size="${SIZE},${SIZE}" \
    --screenshot="$OUT/icon_${SIZE}.png" \
    "file://$TMP/page.html" >/dev/null 2>&1

  # A rasteriser that quietly writes a 0x0 or wrong-sized file would otherwise
  # sail through and produce a blank icon in Finder.
  ACTUAL=$(sips -g pixelWidth "$OUT/icon_${SIZE}.png" | awk '/pixelWidth/{print $2}')
  if [ "$ACTUAL" != "$SIZE" ]; then
    echo "render failed at ${SIZE}px (got ${ACTUAL})" >&2
    exit 1
  fi
  echo "  ${SIZE}x${SIZE}"
done

rm -rf "$TMP"

cat > "$OUT/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16.png",   "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_32.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png",   "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_64.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png",  "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_256.png",  "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png",  "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_512.png",  "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png",  "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "wrote $OUT"
