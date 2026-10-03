#!/usr/bin/env python3
"""Print HaikuPorts SOURCE_URI_n / CHECKSUM_SHA256_n lines for a Cargo.lock.

Usage: gen-crate-uris.py path/to/Cargo.lock [first_index]

Every registry crate in the lockfile is listed, using the lockfile's own
sha256 (which is the sha256 of the .crate file on static.crates.io).
first_index defaults to 2, since SOURCE_URI (index 1) is the project tarball.
The recipe's BUILD() loop must run `seq 2 <last index>`; the last index is
printed to stderr.
"""

import sys
import tomllib


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    first = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    with open(sys.argv[1], "rb") as f:
        lock = tomllib.load(f)

    crates = [p for p in lock["package"] if p.get("source", "").startswith("registry+")]
    missing = [p["name"] for p in crates if "checksum" not in p]
    if missing:
        print(f"crates without a checksum: {', '.join(missing)}", file=sys.stderr)
        return 1

    for i, p in enumerate(crates, start=first):
        name, version = p["name"], p["version"]
        print(f'SOURCE_URI_{i}="https://static.crates.io/crates/{name}/{name}-{version}.crate"')
        print(f'CHECKSUM_SHA256_{i}="{p["checksum"]}"')
        print()
    print(f"last index: {first + len(crates) - 1}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
