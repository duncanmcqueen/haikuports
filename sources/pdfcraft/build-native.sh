#!/bin/bash
set -u
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
export LD_PRELOAD=/boot/home/rust/libnofilemmap.so
export CARGO_BUILD_JOBS=2
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/boot/home/rust/pdfcraft-port/src/apps/pdfcraft-haiku/target}"
export CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16
cd /boot/home/rust/pdfcraft-port/src || exit 1
printf 'BUILD running\n' > ../status
cargo build --release --locked --manifest-path apps/pdfcraft-haiku/Cargo.toml > ../build.log 2>&1
code=$?
printf 'BUILD exit=%s\nDONE\n' "$code" > ../status
exit "$code"
