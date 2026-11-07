#!/usr/bin/env bash
# Build the maintained libmpv source; system FFmpeg/graphics remain dependencies.
set -euo pipefail
root="$(realpath -m "${1:?native build directory required}")"
script="$(cd "$(dirname "$0")" && pwd)"
mapfile -t pin < <(python3 - "$script/mpv-source.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
print(data["url"])
print(data["sha256"])
print(data["commit"])
PY
)
[[ ${#pin[@]} == 3 && "${pin[1]}" =~ ^[0-9a-f]{64}$ ]] || exit 1
mkdir -p "$root"
archive="$root/mpv-${pin[2]}.tar.gz"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --retry 3 --max-time 180 "${pin[0]}" -o "$archive.partial"
  printf '%s  %s\n' "${pin[1]}" "$archive.partial" | sha256sum -c -
  mv "$archive.partial" "$archive"
fi
printf '%s  %s\n' "${pin[1]}" "$archive" | sha256sum -c -
source="$root/source-${pin[2]}"
if [[ ! -f "$source/meson.build" ]]; then
  mkdir -p "$source"
  tar -xzf "$archive" --strip-components=1 -C "$source"
fi
options=(--prefix="$root/install" --libdir=lib --buildtype=release
  --wrap-mode=nodownload -Dlibmpv=true -Dcplayer=false -Dgpl=false
  -Dbuild-date=false -Dtests=false -Dgl=enabled -Dplain-gl=enabled
  -Degl=enabled -Dvaapi=enabled -Dvulkan=disabled)
if [[ -f "$root/compile/build.ninja" ]]; then
  meson setup --reconfigure "$root/compile" "$source" "${options[@]}"
else
  meson setup "$root/compile" "$source" "${options[@]}"
fi
meson compile -C "$root/compile" -j "${MEDIA_KIT_BUILD_JOBS:-4}"
meson install -C "$root/compile" --no-rebuild
cp -L "$root/install/lib/libmpv.so.2" "$root/libmpv.so.2.partial"
mv "$root/libmpv.so.2.partial" "$root/libmpv.so.2"
cp "$script/mpv-source.json" "$root/SOURCE.json"
