#!/bin/bash
# Phase 1+2: build the 1.99.0 dist tarballs natively, with the chain's 1.98.0 as stage0
# and the system llvm23 (static) as LLVM.
# Pipelining lets dependents mmap a crate's .rmeta while it is still being written;
# on Haiku that coincides with page corruption in build outputs. Turn it off.
export CARGO_BUILD_PIPELINING=false
# Experiment: keep every rustc/cargo/ld file read off the mmap path (see nofilemmap.c).
[ -n "${NOFILEMMAP:-1}" ] && [ -f ~/rust/libnofilemmap.so ] && export LD_PRELOAD=~/rust/libnofilemmap.so
# packagefs on this VM does not show openssl3_devel files; use an extracted copy.
[ -d ~/rust/ossl/include/openssl ] && export OPENSSL_INCLUDE_DIR=~/rust/ossl/include OPENSSL_LIB_DIR=~/rust/ossl/lib
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
V=1.99.0
R=~/rust
S=$R/status-dist
prev=$R/stage0-1.98.0
. $R/xpy-retry.sh
fail() { echo "FAIL $*" >> $S; exit 1; }
inst=$(pkgman search -i llvm22 2>/dev/null | awk '$1=="S"||$1=="s"{print $2}' | grep -E '^llvm22(_clang|_lld|_clang_analysis)?$')
[ -n "$inst" ] && pkgman uninstall -y $inst >> $R/dist-pkgman.log 2>&1
pkgman install -y llvm23 llvm23_libs llvm23_clang llvm23_lld >> $R/dist-pkgman.log 2>&1
got=$(llvm-config --version); echo "LLVM want=23 got=$got $(date +%T)" >> $S
[ "${got%%.*}" = 23 ] || fail llvm
cd $R/rustc-$V-src
python3 $R/patch-std-flock.py . >> $S 2>&1 || fail patch
sed -e "s|^rustc = .*|rustc = \"$prev/bin/rustc\"|" -e "s|^cargo = .*|cargo = \"$prev/bin/cargo\"|" \
    $R/bootstrap-199.toml > bootstrap.toml
xpy $R/dist-$V.log dist; rc=$?
echo "DIST=$rc $(date +%T)" >> $S; [ $rc = 0 ] || fail dist
ls -la build/dist >> $S
echo DONE >> $S
