#!/bin/sh
# Build the standard bundled package on a supported build host.
set -eu
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec sh "$here/scripts/build.sh" bundled "$@"
