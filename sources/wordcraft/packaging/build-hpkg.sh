#!/bin/bash
# Package the tested GUI and CLI artifacts without recompiling them.
set -eu
if [ "$(uname -s)" != Haiku ] || [ "$#" != 5 ]; then
    echo "Usage (on Haiku): $0 GUI_R3_DIRECTORY CLI_BINARY ICON_DIRECTORY NEW_OUTPUT_DIRECTORY PACKAGER" >&2
    exit 2
fi
gui=$1
cli=$2
icons=$3
out=$4
packager=$5
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ ! -e "$out" ] || { echo "Output exists: $out" >&2; exit 1; }
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
unset LD_PRELOAD
mkdir -p "$out/stage/apps/Wordcraft" "$out/stage/bin" \
    "$out/stage/data/deskbar/menu/Applications" "$out/stage/data/licenses" \
    "$out/stage/documentation/packages/wordcraft"
stage=$out/stage
cp "$gui/wordcraft-haiku.bin" "$stage/apps/Wordcraft/Wordcraft"
cp "$cli" "$stage/bin/wordcraft-cli"
chmod 755 "$stage/apps/Wordcraft/Wordcraft" "$stage/bin/wordcraft-cli"
cp -R "$gui/licenses" "$stage/documentation/packages/wordcraft/"
cp -R "$gui/patches" "$stage/documentation/packages/wordcraft/"
cp "$gui/README.md" "$gui/GUI-NOTES.md" "$gui/SAVE-AS-NOTES.md" \
    "$stage/documentation/packages/wordcraft/"
cp "$gui/licenses/THIRD-PARTY.txt" "$stage/data/licenses/Wordcraft third-party notices"
ln -s ../../../../apps/Wordcraft/Wordcraft "$stage/data/deskbar/menu/Applications/Wordcraft"
cp "$script_dir/PackageInfo" "$stage/.PackageInfo"
python3 - "$stage/.PackageInfo" "$packager" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = '\n'.join('packager ' + json.dumps(sys.argv[2]) if l.startswith('packager ') else l for l in s.splitlines()) + '\n'
p.write_text(s)
PY
rc -o "$out/Wordcraft.rsrc" "$script_dir/Wordcraft.rdef"
xres -o "$stage/apps/Wordcraft/Wordcraft" "$out/Wordcraft.rsrc"
g++ -O2 -o "$out/set-icon" "$script_dir/set-icon.cpp" -lbe -ltranslation
"$out/set-icon" "$stage/apps/Wordcraft/Wordcraft" \
    "$icons/32x32/apps/ai.storyteller.wordcraft.png" \
    "$icons/16x16/apps/ai.storyteller.wordcraft.png"
mimeset -f "$stage/apps/Wordcraft/Wordcraft"
package create -C "$stage" "$out/wordcraft-0.6.1-2-x86_64.hpkg"
package list -i "$out/wordcraft-0.6.1-2-x86_64.hpkg" > "$out/package-info.txt"
sha256sum "$out/wordcraft-0.6.1-2-x86_64.hpkg" > "$out/SHA256SUMS"
echo "Created $out/wordcraft-0.6.1-2-x86_64.hpkg"
