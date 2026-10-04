#!/bin/bash
# Walk the stage0 chain natively: each release is built by the previous one.
# Usage: chain.sh <ver>...   (e.g. chain.sh 1.95.0 1.96.0 1.97.0 1.98.0)
# Each step produces ~/rust/stage0-<ver> (stage1 rustc + std + cargo).
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
S=~/rust/status-chain
R=~/rust

. $R/xpy-retry.sh
R=~/rust
prev=/boot/system/develop/tools/rust
[ -f $R/chain-prev ] && prev=$(cat $R/chain-prev)
for v in "$@"; do
  llvm=$(grep -o 'LLVM_VERSION_MAJOR [0-9]*' $R/rustc-$v-src/src/llvm-project/cmake/Modules/LLVMVersion.cmake 2>/dev/null | awk '{print $2}')
  if [ ! -d $R/rustc-$v-src ]; then
    tar xf $R/rustc-$v-src.tar.xz -C $R; echo "UNPACK $v=$? $(date +%T)" >> $S
    llvm=$(grep -o 'LLVM_VERSION_MAJOR [0-9]*' $R/rustc-$v-src/src/llvm-project/cmake/Modules/LLVMVersion.cmake | awk '{print $2}')
  fi
  have=$(llvm-config --version 2>/dev/null | cut -d. -f1)
  if [ "$have" != "$llvm" ]; then
    for o in 21 22 23; do
      [ $o = $llvm ] && continue
      inst=$(pkgman search -i llvm$o 2>/dev/null | awk '$1=="S"||$1=="s"{print $2}' | grep -E "^llvm${o}(_clang|_lld|_clang_analysis)?$")
      [ -n "$inst" ] && pkgman uninstall -y $inst >> $R/chain-pkgman.log 2>&1
    done
    pkgman install -y llvm${llvm} llvm${llvm}_libs >> $R/chain-pkgman.log 2>&1
    got=$(llvm-config --version 2>/dev/null)
    echo "LLVM $v want=$llvm got=$got $(date +%T)" >> $S
    [ "${got%%.*}" = "$llvm" ] || { echo FAIL >> $S; exit 1; }
  fi
  cd $R/rustc-$v-src
  # std before 1.95-with-patch cannot flock on Haiku; only then bypass the build lock.
  bypass=; [ "$prev" = /boot/system/develop/tools/rust ] && bypass=--bypass-bootstrap-lock
  sed -e "s|^rustc = .*|rustc = \"$prev/bin/rustc\"|" -e "s|^cargo = .*|cargo = \"$prev/bin/cargo\"|" \
      -e 's|^extended = .*|extended = false|' -e '/^tools = /d' $R/bootstrap-199.toml > bootstrap.toml
  python3 $R/patch-std-flock.py . >> $S 2>&1 || { echo FAIL >> $S; exit 1; }
  xpy $R/build-$v.log build $bypass --stage 1 library; rc=$?
  echo "BUILD $v library=$rc $(date +%T)" >> $S
  [ $rc = 0 ] || { echo FAIL >> $S; exit 1; }
  xpy $R/build-$v-cargo.log build $bypass --stage 1 cargo; rc=$?
  echo "BUILD $v cargo=$rc $(date +%T)" >> $S
  [ $rc = 0 ] || { echo FAIL >> $S; exit 1; }
  out=$R/stage0-$v
  rm -rf $out; cp -a build/x86_64-unknown-haiku/stage1 $out
  c=$(ls -t build/x86_64-unknown-haiku/stage*-tools-bin/cargo build/x86_64-unknown-haiku/stage*-tools/*/release/cargo 2>/dev/null | head -1)
  cp "$c" $out/bin/cargo
  ln -sfn ../lib $out/bin/lib
  echo "STAGE0 $v rustc=[$($out/bin/rustc --version)] cargo=[$($out/bin/cargo --version)] $(date +%T)" >> $S
  echo $out > $R/chain-prev
  prev=$out
  rm -rf build/x86_64-unknown-haiku/stage0* build/x86_64-unknown-haiku/stage1-* 2>/dev/null
done
echo DONE >> $S
