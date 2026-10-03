#!/bin/sh
# Build haiku_agent_library-0.1.0-1-any.hpkg on Haiku from the library archive.
set -eu
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
archive="$here/haiku-agent-library.zip"
out="${1:-$PWD/haiku_agent_library-0.1.0-1-any.hpkg}"
[ -f "$archive" ] || { echo "Missing $archive" >&2; exit 1; }
[ "$(uname -s)" = Haiku ] || { echo 'Build this package on Haiku.' >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unzip -q "$archive" -d "$work"
lib="$work/haiku-agent-library"
[ -d "$lib" ] || { echo 'Archive does not contain haiku-agent-library/.' >&2; exit 1; }

root="$work/root"
mkdir -p "$root/data/haiku-agent-library"
cp -a "$lib/." "$root/data/haiku-agent-library/"
cat > "$root/.PackageInfo" <<'EOF'
name haiku_agent_library
version 0.1.0-1
architecture any
summary "Haiku OS coding context for AI agents"
description "Agent Skills and the Haiku Book sources for coding agents such as pi and Maki that work on Haiku OS code."
packager "pi-on-haiku contributors"
vendor "Haiku Project"
licenses {
    "MIT"
}
copyrights {
    "2026 Duncan McQueen"
}
provides {
    haiku_agent_library = 0.1.0-1
}
requires {
    haiku
}
EOF
( cd "$root" && package create -q -i .PackageInfo "$out" )
echo "Created $out"
