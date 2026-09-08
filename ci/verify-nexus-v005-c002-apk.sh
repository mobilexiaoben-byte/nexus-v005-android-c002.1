#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${1:?usage: verify-nexus-v005-c002-apk.sh <project-root> <apk-path>}"
APK="${2:?usage: verify-nexus-v005-c002-apk.sh <project-root> <apk-path>}"

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
APK="$(cd "$(dirname "$APK")" && pwd)/$(basename "$APK")"
AAPT="${ANDROID_HOME:?ANDROID_HOME is required}/build-tools/36.0.0/aapt"

test -f "$APK"
test -x "$AAPT"

BADGING="$("$AAPT" dump badging "$APK")"
printf '%s\n' "$BADGING" | grep -q "application:.*icon='res/mipmap-mdpi-v4/ic_launcher.png'"

for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  unzip -l "$APK" | grep -q "res/mipmap-${density}-v4/ic_launcher.png"
  unzip -l "$APK" | grep -q "res/mipmap-${density}-v4/ic_launcher_round.png"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  packaged="res/mipmap-${density}-v4/ic_launcher.png"
  unzip -p "$APK" "$packaged" > "$TMP/${density}.png"
  source="$PROJECT_ROOT/app/src/main/res/mipmap-${density}/ic_launcher.png"
  test -f "$source"
  # Android packaging may change PNG encoding, so compare decoded pixels.
  diff_pixels="$(compare -metric AE "$source" "$TMP/${density}.png" null: 2>&1 || true)"
  test "$diff_pixels" = "0"
done

echo 'NEXUS V005/C002 APK launcher verification: PASS'
