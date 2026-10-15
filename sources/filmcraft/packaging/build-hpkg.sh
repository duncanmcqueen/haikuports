#!/bin/bash
set -eu
base=/boot/home/rust/filmcraft-port
out=$base/package-r4
stage=$out/stage
[ ! -e "$out" ] || { echo "Output exists: $out" >&2; exit 1; }
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
unset LD_PRELOAD
mkdir -p "$stage/apps/Filmcraft" "$stage/bin" "$stage/data/deskbar/menu/Applications" "$stage/data/licenses" "$stage/documentation/packages/filmcraft"
cp "$base/src/apps/filmcraft-haiku/target/release/filmcraft-haiku" "$stage/apps/Filmcraft/Filmcraft"
chmod 755 "$stage/apps/Filmcraft/Filmcraft"
cp "$base/packaging/PackageInfo" "$stage/.PackageInfo"
cp -R "$base/packaging/licenses" "$stage/documentation/packages/filmcraft/"
cp -R "$base/patches" "$stage/documentation/packages/filmcraft/"
cp "$base/PORT-NOTES.md" "$stage/documentation/packages/filmcraft/"
cp "$base/src/NOTICE" "$base/src/ATTRIBUTION.md" "$stage/documentation/packages/filmcraft/"
cp "$base/packaging/licenses/THIRD-PARTY.txt" "$stage/data/licenses/Filmcraft third-party notices"
ln -s ../apps/Filmcraft/Filmcraft "$stage/bin/filmcraft"
ln -s ../../../../apps/Filmcraft/Filmcraft "$stage/data/deskbar/menu/Applications/Filmcraft"
rc -o "$out/Filmcraft.rsrc" "$base/packaging/Filmcraft.rdef"
xres -o "$stage/apps/Filmcraft/Filmcraft" "$out/Filmcraft.rsrc"
mimeset -f "$stage/apps/Filmcraft/Filmcraft"
package create -C "$stage" "$out/filmcraft-0.8.0-4-x86_64.hpkg"
package list -i "$out/filmcraft-0.8.0-4-x86_64.hpkg" > "$out/package-info.txt"
sha256sum "$out/filmcraft-0.8.0-4-x86_64.hpkg" > "$out/SHA256SUMS"
