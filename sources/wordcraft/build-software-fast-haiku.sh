#!/bin/bash
set -u
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
export LD_PRELOAD=/boot/home/rust/libnofilemmap.so
export CARGO_BUILD_JOBS=2
export CARGO_PROFILE_RELEASE_LTO=false
cd /boot/home/rust/wordcraft-port/src || exit 1
printf 'BUILD running\n' > ../software-status
cargo build --release --locked --offline -p wordcraft-haiku > ../software-final-build.log 2>&1
result=$?
printf 'BUILD exit=%s\nDONE\n' "$result" > ../software-status
exit "$result"
