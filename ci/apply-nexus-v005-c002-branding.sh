#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${1:?usage: apply-nexus-v005-c002-branding.sh <project-root> <icon-path>}"
ICON="${2:?usage: apply-nexus-v005-c002-branding.sh <project-root> <icon-path>}"

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
ICON="$(cd "$(dirname "$ICON")" && pwd)/$(basename "$ICON")"
MANIFEST="$PROJECT_ROOT/app/src/main/AndroidManifest.xml"
RES="$PROJECT_ROOT/app/src/main/res"

command -v convert >/dev/null
command -v identify >/dev/null
command -v python3 >/dev/null

test -f "$ICON"
test -f "$MANIFEST"
file "$ICON" | grep -q 'PNG image data'
identify -format '%m %wx%h\n' "$ICON" | grep -q '^PNG 1536x1536$'

python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
if '<application' not in s:
    raise SystemExit('No <application> element in AndroidManifest.xml')
if re.search(r'android:icon="[^"]+"', s):
    s = re.sub(r'android:icon="[^"]+"', 'android:icon="@mipmap/ic_launcher"', s, count=1)
else:
    s = s.replace('<application', '<application android:icon="@mipmap/ic_launcher"', 1)
if re.search(r'android:roundIcon="[^"]+"', s):
    s = re.sub(r'android:roundIcon="[^"]+"', 'android:roundIcon="@mipmap/ic_launcher_round"', s, count=1)
else:
    s = s.replace('<application', '<application android:roundIcon="@mipmap/ic_launcher_round"', 1)
p.write_text(s, encoding='utf-8')
PY

# Remove adaptive-icon overrides that could supersede the canonical bitmap launcher.
find "$RES" -type f \( \
  -path '*/mipmap-anydpi*/ic_launcher.xml' -o \
  -path '*/mipmap-anydpi*/ic_launcher_round.xml' \
\) -print -delete || true

make_icon() {
  local size="$1" dir="$2"
  mkdir -p "$RES/$dir"
  convert "$ICON" -resize "${size}x${size}" "$RES/$dir/ic_launcher.png"
  cp "$RES/$dir/ic_launcher.png" "$RES/$dir/ic_launcher_round.png"
}

make_icon 48  mipmap-mdpi
make_icon 72  mipmap-hdpi
make_icon 96  mipmap-xhdpi
make_icon 144 mipmap-xxhdpi
make_icon 192 mipmap-xxxhdpi

grep -q 'android:icon="@mipmap/ic_launcher"' "$MANIFEST"
grep -q 'android:roundIcon="@mipmap/ic_launcher_round"' "$MANIFEST"

for spec in \
  'mipmap-mdpi 48' \
  'mipmap-hdpi 72' \
  'mipmap-xhdpi 96' \
  'mipmap-xxhdpi 144' \
  'mipmap-xxxhdpi 192'; do
  set -- $spec
  dir="$1" size="$2"
  identify -format '%m %wx%h\n' "$RES/$dir/ic_launcher.png" | grep -q "^PNG ${size}x${size}$"
  identify -format '%m %wx%h\n' "$RES/$dir/ic_launcher_round.png" | grep -q "^PNG ${size}x${size}$"
done

echo 'NEXUS V005/C002 branding baseline: PASS'
