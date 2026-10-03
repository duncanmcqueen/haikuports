#!/bin/sh
# Rebuild the maintained Node port in a separate HaikuPorts tree.
set -eu
usage() {
    echo 'Usage: sh scripts/rebuild-node-haiku.sh --packager "Name <email>" [--work DIRECTORY] [--tree-source GIT_REPO] [--jobs N] [--prepare-only] [--clean]'
}
here=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work="$HOME/nodejs22-rebuild"
jobs=3
packager=${PACKAGER:-}
prepare=false
clean=false
tree_ref=a3c47c01ac34878981ed7dfbe52d823e2c8fb503
tree_source=https://github.com/haikuports/haikuports.git
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --work|--tree-source|--jobs|--packager)
            [ "$#" -ge 2 ] && [ -n "$2" ] || { usage >&2; exit 2; }
            case "$1" in --work) work=$2 ;; --tree-source) tree_source=$2 ;; --jobs) jobs=$2 ;; --packager) packager=$2 ;; esac
            shift 2 ;;
        --prepare-only) prepare=true; shift ;;
        --clean) clean=true; shift ;;
        *) usage >&2; exit 2 ;;
    esac
done
export LIBRARY_PATH="/boot/system/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
[ "$(uname -s)" = Haiku ] && [ "$(uname -m)" = x86_64 ] || {
    echo 'Run this script on Haiku x86_64.' >&2; exit 1;
}
case "$jobs" in ''|*[!0-9]*|0) echo 'Jobs must be a positive integer.' >&2; exit 2 ;; esac
case "$jobs" in *[1-9]*) ;; *) echo 'Jobs must be greater than zero.' >&2; exit 2 ;; esac
while [ "${jobs#0}" != "$jobs" ]; do jobs=${jobs#0}; done
[ -n "$packager" ] || { echo 'Set --packager or PACKAGER.' >&2; exit 2; }
# These values are inserted into a HaikuPorter configuration file.
case "$work$packager" in *'"'*|*'\'*|*'$'*|*'`'*|*'
'*) echo 'Paths and packager values must not contain quotes, backslashes, or newlines.' >&2; exit 2 ;; esac
case "$work" in /*) ;; *) work="$PWD/$work" ;; esac
for tool in git haikuporter sha256sum cmp; do
    command -v "$tool" >/dev/null || { echo "Missing command: $tool" >&2; exit 1; }
done
mkdir -p "$work"
work=$(CDPATH= cd -- "$work" && pwd)
case "$work" in *'"'*|*'\'*|*'$'*|*'`'*|*'
'*) echo 'Resolved work path is not safe for a shell configuration.' >&2; exit 2 ;; esac
lock="$work/.nodejs22-build-lock"
mkdir "$lock" || { echo "Another build owns $work (or a stale lock remains)." >&2; exit 1; }
phase=PREPARING
completed=false
initial=
cleanup() {
    result=$?
    set +e
    if [ "$completed" = false ]; then
        printf 'FAILED phase=%s exit=%s\n' "$phase" "$result" > "$work/status"
    fi
    [ -z "$initial" ] || rm -rf "$initial"
    rmdir "$lock"
    return "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo PREPARING > "$work/status"
tree="$work/haikuports"
if [ ! -e "$tree" ]; then
    initial=$(mktemp -d "$work/.ports-init.XXXXXX")
    git clone --no-hardlinks --no-checkout "$tree_source" "$initial/tree"
    git -C "$initial/tree" checkout --detach "$tree_ref"
    mv "$initial/tree" "$tree"
    rmdir "$initial"
    initial=
fi
[ "$(git -C "$tree" rev-parse HEAD)" = "$tree_ref" ] || {
    echo 'This work directory has a different HaikuPorts revision. Select a new --work directory.' >&2; exit 1;
}
port=net-libs/nodejs
for relative in "$port/nodejs22-22.23.3.recipe" "$port/patches/nodejs-22.23.3.patchset"; do
    if [ ! -f "$tree/$relative" ] || ! cmp -s "$here/haikuports/$relative" "$tree/$relative"; then
        cp -f "$here/haikuports/$relative" "$tree/$relative"
    fi
done
config="$work/haikuports.conf"
printf 'TREE_PATH="%s"\nPACKAGER="%s"\nALLOW_UNTESTED="yes"\n' "$tree" "$packager" > "$config"
{
    printf 'HaikuPorts revision: %s\n' "$tree_ref"
    uname -a
    haikuporter --version
    sha256sum "$here/haikuports/$port/nodejs22-22.23.3.recipe" "$here/haikuports/$port/patches/nodejs-22.23.3.patchset"
} > "$work/build-inputs.txt"
phase=LINT
echo LINTING > "$work/status"
haikuporter --config "$config" --lint nodejs22
if [ "$prepare" = true ]; then
    echo PREPARED > "$work/status"
    completed=true
    echo "Prepared $work. No compiler or package build was started."
    exit 0
fi
set -- --config "$config" --get-dependencies --no-source-packages -j "$jobs"
[ "$clean" = false ] || set -- "$@" --force
echo BUILDING > "$work/status"
phase=BUILD
echo "Build log: $work/build.log"
if haikuporter "$@" nodejs22 > "$work/build.log" 2>&1; then
    echo 'BUILD exit=0' > "$work/status"
else
    result=$?
    echo "Build failed. Read $work/build.log. Re-run without --clean to resume." >&2
    exit "$result"
fi
phase=OUTPUT
set -- "$tree"/packages/nodejs22-22.23.3-*-x86_64.hpkg "$tree"/packages/nodejs22_devel-22.23.3-*-x86_64.hpkg
for artifact in "$@"; do
    [ -f "$artifact" ] || { echo "Missing output: $artifact" >&2; exit 1; }
done
sha256sum "$@" > "$work/package-checksums.txt"
echo DONE > "$work/status"
completed=true
echo "Packages: $tree/packages"
echo 'Install the new package revision, verify node --version, and test Intl, workers, and GC before publishing.'
