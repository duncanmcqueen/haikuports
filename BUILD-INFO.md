# Current package set

Initial publication: 2026-10-03. These are existing HaikuPorter-built packages from
the owner's VM. No compilation or rebuild was performed for this publication.

| Package | Version | Purpose |
| --- | --- | --- |
| nodejs22 | 22.23.3-1 | Node runtime and Corepack |
| nodejs22_devel | 22.23.3-1 | Optional Node development files |
| icu77 | 77.1-1 | Runtime dependency of this compiled Node binary |
| icu77_devel | 77.1-1 | Optional ICU development files |
| icu77_tools | 77.1-1 | Optional ICU tools |

All packages declare vendor `Haiku Project`, as produced by the existing recipes.
That vendor field does not imply that Haiku or HaikuPorts endorses this repository.
The original artifacts identify their packager as `VM Builder <vm@localhost>`.
They have not been relabeled or stripped of upstream license metadata.

## Verification performed before publication

- Extracted `bin/node` from the package selected for publication and ran that binary.
- `process.version`: `v22.23.3`.
- `process.versions.icu`: `77.1`.
- `os.cpus()` returned an array with six entries on the test VM.
- `Intl.DateTimeFormat('de-DE')` locale check passed.
- Garbage collection, four worker threads, and in-memory SQLite checks passed.
- ELF dependencies include `libicui18n.so.77` and `libicuuc.so.77`.
- Package requirements also identify ICU 77.1. ICU 74 is not a binary replacement.
- Standalone `pkgman resolve-dependencies` passed for the runtime/development packages.
  Candidate dependencies were official-package files plus this repository's packages.
  Installed personal Node, ICU 77, and the local guard package were excluded.
- All index/package SHA-256 checksums passed.

The test kernel reported Haiku R1/beta6 hrev59866+79, x86_64. This was an existing
VM, not a newly installed VM. A successful dependency-solver check does not replace
a full fresh-install test. The official repositories may update system dependencies
during installation on an older beta6 system.

## Source and rebuilds

The maintained Node recipe and patches in the owner's private `pi-on-haiku` repository
have evolved since these existing binaries were built. Metadata edits and newly
reviewed source changes do not retroactively change a compiled package.
The rebuild script records recipe/patch hashes and the pinned HaikuPorts tree revision
for the next build. A new binary must be validated and given a new package revision
before it replaces a package in this repository.

Package-specific source URLs and licenses remain embedded in the `.hpkg` metadata.
The channel's `SHA256SUMS` contains hashes for every currently indexed package.
AI assistance, human review, and the AS-IS terms are described in the README.
