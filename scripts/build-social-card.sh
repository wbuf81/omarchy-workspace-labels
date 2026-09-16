#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

command -v magick >/dev/null
command -v fc-match >/dev/null

font_file="$(fc-match -f '%{file}\n' 'JetBrains Mono' | head -n 1)"
test -n "$font_file"

scratch_dir="$(mktemp -d)"
trap 'rm -rf -- "$scratch_dir"' EXIT

# Frame only real running-plugin captures. The generated background remains an
# atmospheric layer and never pretends to be application UI.
magick docs/preview.png -crop 345x215+28+26 +repage -resize 470x \
  -bordercolor '#6fe7f2' -border 2x2 \
  \( +clone -background '#000000' -shadow 70x14+0+16 \) \
  +swap -background none -layers merge +repage \
  "$scratch_dir/preview.png"

magick docs/bar.png -resize 520x \
  -bordercolor '#15243a' -border 16x14 \
  -bordercolor '#6fe7f2' -border 2x2 \
  \( +clone -background '#000000' -shadow 65x10+0+10 \) \
  +swap -background none -layers merge +repage \
  "$scratch_dir/bar.png"

magick assets/social/share-card-background.png \
  -resize '1280x640^' -gravity center -extent 1280x640 \
  -gravity northwest \
  \( -size 1280x640 gradient:'#05070d00-#05070dcc' -rotate 90 \) \
  -compose over -composite \
  \( "$scratch_dir/preview.png" -geometry +735+145 \) \
  -compose over -composite \
  \( "$scratch_dir/bar.png" -geometry +650+500 \) \
  -compose over -composite \
  -font "$font_file" \
  -fill '#7aa2f7' -pointsize 18 -draw "text 72,96 'OMARCHY PLUGIN  /  v3.1.1'" \
  -fill '#f4f7ff' -pointsize 55 -draw "text 70,184 'WORKSPACE' text 70,252 'LABELS'" \
  -fill '#c5ccdc' -pointsize 22 -draw "text 72,315 'Names and real app icons for' text 72,350 'the workspaces you actually use.'" \
  -fill '#6fe7f2' -pointsize 17 -draw "text 72,423 'PREVIEW  •  EDIT  •  SWITCH'" \
  -fill '#919bb2' -pointsize 15 -draw "text 72,580 'github.com/wbuf81/omarchy-workspace-labels'" \
  -strip -define png:bit-depth=8 -define png:compression-level=9 \
  docs/social-preview.png

echo "built docs/social-preview.png"
