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
| fd | 10.5.0-1 | File-search tool used by the pi coding agent |
| pi | 1.0.0-1 | The pi coding agent, unbundled build |
| haiku_agent_library | 0.1.0-1 | Haiku developer skills for pi, including the Haiku Book |

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
- After GitHub Pages deployment, Haiku downloaded all five packages and the index
  over HTTPS. Their checksums matched the published manifest.
- `pkgman add-repo` registered `DuncanHaikuPackages` successfully, and
  `pkgman refresh DuncanHaikuPackages` validated its index.
- A `pkgman full-sync` check with the repository registered reported `Nothing to do`.

The test kernel reported Haiku R1/beta6 hrev59866+79, x86_64. This was an existing
VM, not a newly installed VM. A successful dependency-solver check does not replace
a full fresh-install test. The official repositories may update system dependencies
during installation on an older beta6 system.

## pi and haiku_agent_library

- `pi` was built from the tested unbundled output (`build-info.json` records source
  commit `9fba660cf1caca0ade5bea72269352416e595a19`, pi 1.0.0). Its `bin/pi` symlink
  resolves within the package. The extracted command reports `1.0.0`.
- `haiku_agent_library` packages the owner's Haiku agent library: `AGENTS.md`, the
  `haiku-api` skill with the Haiku Book sources, and the `haikuports-recipe` skill.
- Both are `architecture any` and are served from this repository.
- On the test VM, `pkgman install pi haiku_agent_library` downloaded both packages
  over HTTPS and validated their checksums. System-package activation requires a
  reboot; the extracted `bin/pi` was run instead and reported `1.0.0`.

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

## maki 0.6.0

`maki-0.6.0-1` (and `maki_debuginfo-0.6.0-1`) was built with HaikuPorter on the
owner's VM from upstream `v0.6.0` plus the two-commit patchset in `sources/maki`.
The toolchain was `rustc`/`cargo` 1.99.0; the build links the system libcurl 8.22,
OpenSSL 3.5, and zlib.

Verification before publication:

- `maki --version` reports `maki 0.6.0`.
- `maki models` lists the configured model without error.
- `maki -p "Reply with exactly: MAKI060_OK"` returned `MAKI060_OK`.
- On the native `XDG_STATE_HOME=/boot/home/config/var` path, maki wrote
  `/boot/home/config/var/logs/maki/maki.log` when started through the local
  `sources/maki/maki-launcher` wrapper.
- Extracted-package SHA-256 `maki-0.6.0-1-x86_64.hpkg`:
  `0ff64de87661ee3de7ae4ee8c0edd9726ac83997a4318cedd1a91d3b1e233328`.
- The test kernel reported Haiku R1/beta6 hrev59866+88, x86_64.

The previous `maki-0.5.7-1` files remain on the site for older indexes but are not
in the current index. An upstream support request with the source changes needed on
Haiku is at `tontinton/maki` issue 1199.
