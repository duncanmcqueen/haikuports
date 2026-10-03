#!/bin/sh
set -eu
mode=${1:-}
[ $# -eq 0 ] || shift
case "$mode" in
    haiku|bundled) ;;
    *) echo 'Usage: build.sh haiku|bundled [--ref COMMIT] [--out NEW_DIRECTORY]' >&2; exit 2 ;;
esac
here="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# This commit completed the experimental build on Haiku.
ref=9fba660cf1caca0ade5bea72269352416e595a19
out="$PWD/pi-haiku"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --ref|--out)
            [ "$#" -ge 2 ] && [ -n "$2" ] || { echo "$1 needs a value." >&2; exit 2; }
            case "$1" in --ref) ref=$2 ;; --out) out=$2 ;; esac
            shift 2 ;;
        --model-data-from-npm) shift ;; # Both methods now use a versioned model-data package.
        -h|--help) echo 'Usage: pack-pi[-haiku].sh [--ref COMMIT] [--out NEW_DIRECTORY]'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done
for command in node npm git mktemp; do
    command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }
done
node -e 'const [a,b]=process.versions.node.split(".").map(Number); if(a<22||(a===22&&b<19)) process.exit(1)' || {
    echo 'Node.js 22.19 or later is necessary.' >&2; exit 1;
}
# Normalize the path before any directory change. Never remove an existing output.
out=$(node -e 'process.stdout.write(require("node:path").resolve(process.argv[1]))' "$out")
[ ! -e "$out" ] && [ ! -L "$out" ] || { echo "Output already exists: $out" >&2; exit 1; }
parent=$(dirname "$out")
[ -d "$parent" ] || { echo "Output parent does not exist: $parent" >&2; exit 1; }
lock="$out.build-lock"
mkdir "$lock" || { echo "Another build owns this output: $out" >&2; exit 1; }
work=
stage=
cleanup() { [ -z "$work" ] || rm -rf "$work"; [ -z "$stage" ] || rm -rf "$stage"; rmdir "$lock"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
work=$(mktemp -d)
stage=$(mktemp -d "$parent/.pi-build.XXXXXX")
git clone -q https://github.com/earendil-works/pi.git "$work/pi"
cd "$work/pi"
git checkout -q "$ref"
git apply "$here"/pi/0001-*.patch
npm ci --ignore-scripts --no-audit --no-fund
if [ "$mode" = haiku ]; then
    npm install --no-save --ignore-scripts --no-audit --no-fund typescript@5.9.3
    node --input-type=module <<'EOF'
import { readFileSync, writeFileSync } from 'node:fs';
const path = 'packages/coding-agent/package.json';
const p = JSON.parse(readFileSync(path, 'utf8'));
p.scripts.build = 'npm run build:unbundled';
p.bin.pi = 'dist/cli.js';
p.exports['./rpc-entry'].import = './dist/rpc-entry.js';
writeFileSync(path, JSON.stringify(p, null, '\t') + '\n');
EOF
fi
# Match the model-data package to the source package version.
model_version=$(node -p 'require("./packages/ai/package.json").version')
[ "$model_version" = 1.0.0 ] || { echo 'This source needs a new model-data integrity pin.' >&2; exit 1; }
mkdir "$work/model-data"
(cd "$work/model-data" && npm pack --ignore-scripts "@earendil-works/pi-ai@$model_version" >/dev/null)
node --input-type=module - "$work/model-data" <<'EOF'
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
const dir = process.argv[2];
const file = readdirSync(dir).find(n => n.endsWith('.tgz'));
const actual = 'sha512-' + createHash('sha512').update(readFileSync(join(dir, file))).digest('base64');
const expected = 'sha512-3/W1vdDaVtpeMd23ElvJC12HLA5yS/BGqqcXF+0SK082dN7cbgNcCwguTBRBC258Ke8SzSvUW1B75iAf8w8IxA==';
if (actual !== expected) throw Error('Model-data archive integrity does not match the pin');
EOF
tar xzf "$work"/model-data/*.tgz -C "$work/model-data"
mkdir -p packages/ai/src/providers/data
cp -R "$work/model-data/package/dist/providers/data/." packages/ai/src/providers/data/
npm run build:offline
node "$here/scripts/pack-output.mjs" "$stage" "$mode" "$work/model-data" "$here/pi/0001-coding-agent-support-haiku.patch"
cp "$here/scripts/install-on-haiku.sh" "$stage/install-on-haiku.sh"
cp "$here/scripts/smoke-test.mjs" "$stage/smoke-test.mjs"
cp "$here/scripts/check-facets.mjs" "$stage/check-facets.mjs"
cp "$here/scripts/protect-node.sh" "$stage/protect-node.sh"
cp "$here/scripts/pi_haiku_runtime.PackageInfo" "$stage/pi_haiku_runtime.PackageInfo"
chmod +x "$stage/install-on-haiku.sh"
chmod +x "$stage/protect-node.sh"
# Complete the cache on Haiku, including platform-selected optional packages.
if [ "$mode" = haiku ]; then
    (cd "$stage" && npm ci --ignore-scripts --omit=dev --no-audit --no-fund --cache ./npm-cache && node smoke-test.mjs)
    rm -rf "$stage/node_modules"
    (cd "$stage" && npm ci --offline --ignore-scripts --omit=dev --no-audit --no-fund --cache ./npm-cache && node smoke-test.mjs)
    rm -rf "$stage/node_modules"
fi
# npm logs describe transient build paths. Do not distribute them.
rm -rf "$stage/npm-cache/_logs"
[ ! -e "$out" ] && [ ! -L "$out" ] || { echo "Output appeared during the build: $out" >&2; exit 1; }
mv "$stage" "$out"
echo "Build complete: $out"
