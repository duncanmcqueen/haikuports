#!/bin/sh
set -eu
cd "$(dirname "$0")"
node -e 'const [a,b]=process.versions.node.split(".").map(Number); if(a<22||(a===22&&b<19)) process.exit(1)' || {
    echo 'Node.js 22.19 or later is necessary.' >&2; exit 1;
}
# Skip unsupported native postinstall steps. Facet bundles still need esbuild at runtime.
if [ "$(uname -s)" = Haiku ]; then
    sh ./protect-node.sh
fi
backup=$(mktemp -d "$PWD/.pi-install-backup.XXXXXX")
complete=false
installing=false
cleanup() {
    if [ "$complete" = false ]; then
        if [ -e "$backup/node_modules" ] || [ -L "$backup/node_modules" ]; then
            rm -rf node_modules
            mv "$backup/node_modules" node_modules || return 1
        elif [ "$installing" = true ]; then
            rm -rf node_modules
        fi
    fi
    rm -rf "$backup"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [ -e node_modules ] || [ -L node_modules ]; then
    mv node_modules "$backup/node_modules"
fi
installing=true
npm ci --ignore-scripts --omit=dev --no-audit --no-fund --cache ./npm-cache "$@"
node smoke-test.mjs
mkdir -p "$HOME/config/non-packaged/bin"
ln -sf "$PWD/node_modules/.bin/pi" "$HOME/config/non-packaged/bin/pi"
complete=true
echo 'Installation complete. Run: pi'
