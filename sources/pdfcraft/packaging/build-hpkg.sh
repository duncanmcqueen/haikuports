#!/bin/bash
set -eu
base=/boot/home/rust/pdfcraft-port
out=$base/package-r1
stage=$out/stage
target=${CARGO_TARGET_DIR:-$base/src/apps/pdfcraft-haiku/target}
[ ! -e "$out" ] || { echo "Output exists: $out" >&2; exit 1; }
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
unset LD_PRELOAD
mkdir -p "$stage/apps/Pdfcraft" "$stage/bin" "$stage/data/deskbar/menu/Applications" "$stage/data/licenses" "$stage/documentation/packages/pdfcraft"
cp "$target/release/pdfcraft-haiku" "$stage/apps/Pdfcraft/Pdfcraft"
cp "$target/release/pdfcraft-cli" "$stage/bin/pdfcraft-cli"
chmod 755 "$stage/apps/Pdfcraft/Pdfcraft" "$stage/bin/pdfcraft-cli"
cp "$base/packaging/PackageInfo" "$stage/.PackageInfo"
cp -R "$base/packaging/licenses" "$stage/documentation/packages/pdfcraft/"
cp -R "$base/patches" "$stage/documentation/packages/pdfcraft/"
cp "$base/PORT-NOTES.md" "$stage/documentation/packages/pdfcraft/"
cp "$base/src/NOTICE" "$base/src/ATTRIBUTION.md" "$stage/documentation/packages/pdfcraft/"
cp "$base/packaging/licenses/THIRD-PARTY.txt" "$stage/data/licenses/Pdfcraft third-party notices"
ln -s ../apps/Pdfcraft/Pdfcraft "$stage/bin/pdfcraft"
ln -s ../../../../apps/Pdfcraft/Pdfcraft "$stage/data/deskbar/menu/Applications/Pdfcraft"
rc -o "$out/Pdfcraft.rsrc" "$base/packaging/Pdfcraft.rdef"
xres -o "$stage/apps/Pdfcraft/Pdfcraft" "$out/Pdfcraft.rsrc"
mimeset -f "$stage/apps/Pdfcraft/Pdfcraft"
package create -C "$stage" "$out/pdfcraft-0.8.0-1-x86_64.hpkg"
package list -i "$out/pdfcraft-0.8.0-1-x86_64.hpkg" > "$out/package-info.txt"
sha256sum "$out/pdfcraft-0.8.0-1-x86_64.hpkg" > "$out/SHA256SUMS"
