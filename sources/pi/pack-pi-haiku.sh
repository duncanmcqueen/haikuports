#!/bin/sh
# Build the experimental unbundled package on Haiku.
set -eu
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec sh "$here/scripts/build.sh" haiku "$@"
