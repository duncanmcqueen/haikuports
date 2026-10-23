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

## maki 0.6.0-2

Published on 2026-10-14. This revision fixes the polling notification-pipe race
that caused `agent thread terminated with error` / `WouldBlock` at
`isahc-2.0.1/src/agent/mod.rs:252`.

The corrected executable was already built natively on the VM. Revision 2 was
assembled with `package create` from that fixed runtime and its matching debug
package, with package versions raised from 0.6.0-1 to 0.6.0-2. No fresh full
compilation was performed. The older public revision 1 is preserved at its
original URL but is no longer selected by the current index.

The recipe now applies `PATCHES_392="polling-3.11.0.patch"`. Its generator emits
the same declaration, so future builds keep the fix.

Verification:

- On the Mi Air (hrev60232, Rust 1.99), the unmodified polling 3.11.0 concurrent
  wakeup test reported 149 WouldBlock errors. Three runs with the patch reported
  zero errors (36,165, 37,369 and 34,371 waits).
- The dependency patch applies to a clean polling source and yields the tested
  source. Regenerating the recipe from the patched Cargo.lock yields the exact
  maintained recipe. `haikuporter --lint maki-0.6.0` passed.
- The new runtime package was extracted again. Its executable matches the fixed
  input byte for byte and reports `maki 0.6.0`.
- The fixed executable's version and help commands ran on the Mi Air. Normal
  long-running Maki use with the replacement remains unverified.

SHA-256:

- Runtime package: `adff540f24eee176bf8e1f569e133b63c293e127d0e59a50185d75d1aa152f16`.
- Debug package: `2c7935c68355909b2de0722796442ab80d8c66dbf91c58917f2b7baca4815534`.
- Executable: `1ec02261765590ecf90618bddcc96abbb824d08fcc5d26d1e2d73a25d81c0611`.

## maki 0.6.0-1 (historical)

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

## Wordcraft 0.6.1

Published package: `wordcraft-0.6.1-2-x86_64.hpkg`. It contains the tested r3
experimental software-rendered frontend and wordcraft-cli. The package was
assembled natively with `package create` from the existing binaries; this
publication does not claim a new HaikuPorter build. Source commit, dependency
patches and packaging inputs are in `sources/wordcraft/`. AI assistance was used.

- Test VM: Haiku hrev60228 x86_64; compiler Rust/Cargo 1.99.
- Revision 2 embeds native application signature, flags, version and bitmap
  icons in the ELF resources. The version command reads the expected string.
  Revision 1 failed that metadata check and is no longer indexed. Its file is
  retained unchanged for cached indexes.
- A Deskbar Applications link launches the packaged executable.
- Package installation in the home volume passed with no additional packages.
- The installed executable passed native Save As to a filename with spaces,
  Cancel, DOCX content verification, and subsequent Save.
- Installed CLI: `wordcraft-cli 0.6.1`.
- Standalone dependency resolution passed against system package files. The
  dependencies explicitly include the dynamically loaded Wayland libraries,
  in-process server, libxkbcommon and keyboard data.
- Package SHA-256: `f0c7353ccbc2d5b8ca1f49233c0ccfbaed15ed7c386984ecf06fcead95607551`.

The source build previously passed blank-document physical keyboard input,
native Open with a visibly refreshed page, and native close-button exit. Those
are smoke tests, not proof of long-term stability or full document compatibility.
System printing, system clipboard integration and persistent settings are not
wired into the frontend. The Haiku process-exit workaround remains necessary.
The original tar-directory installations are preserved. This package's vendor
field follows the repository convention and does not imply Haiku endorsement.

## Filmcraft 0.8.0

Package: `filmcraft-0.8.0-4-x86_64.hpkg`. Sources, the full port patch, pinned
Cargo.lock, license texts and package builder are in `sources/filmcraft/`.
AI assistance was used. This is an experimental personal package.

- Upstream commit: `9ed9650cad4c9b22cb8d32f4a9ba8050cde20a62`.
- Native build: Haiku hrev60228 x86_64, Rust/Cargo 1.99. It uses the CPU
  compositor, egui software renderer, native file panels and SDL2 audio output.
- Tests passed for short H.264/AAC media import/playback, Razor editing,
  undo/redo, native Save As, project reopen, and one-second H.264/AAC export.
  Exported media decoded without errors in the external test tool.
- Both menu Quit and the native close button passed save-before-close and Cancel.
- The menu row is separate from the toolbar. Both 1100px and 960px layouts
  were inspected. Corrected speaker/moon icon snapping removes NaN geometry
  and the diagonal dotted line. The regression failed before and passes after.
- Eleven focused application tests, all-target clippy and formatting passed.
  Full upstream workspace CI and a clean reconstruction from the published
  source instructions have not been run.
- Revision 3's native package was installed and launched from Deskbar. Revision 4
  packages the same Rust executable with the repository vendor convention and
  an incremented application resource revision. No new Rust build is claimed.
  Its staged executable reports the expected application and CLI versions.
- The native repository builder accepts the new package and all 14 existing
  indexed packages. Existing packages were checked against their old hashes.
- Hardware acceleration and microphone capture are not implemented. Large
  projects, other codecs, clipboard integration and long sessions need testing.
- The package vendor follows the repository convention; it does not imply
  Haiku endorsement. The process-exit workaround remains in use.

SHA-256: `eaf111367f9d9982c85ef7cbf53b222dd787f4f2e6052bffe1f1b574f0cecf4c`.

## Intel Bluetooth firmware 20261019

Package: `intel_bluetooth_firmwares-20261019-1-any.hpkg`. Recipe and license are
in `sources/intel-bluetooth-firmwares/`. AI assistance was used.

- Unmodified files from linux-firmware 20261019 (commit
  `a2dcb924f0897368b0b4f305cbf9808cdda90ce0`): `ibt-11-5.sfi`, `ibt-11-5.ddc`,
  `ibt-12-16.sfi`, `ibt-12-16.ddc`. The recipe checks the SHA-256 of each file.
- Built with HaikuPorter 1.5.3 on Haiku R1/beta6 x86_64; `haikuporter --lint` passed.
- Installed on a Xiaomi Mi Air 12.5 (Intel 8260, hrev60232). The package
  activated, and the files are in `/boot/system/data/firmware/h2generic/`.
- The same `ibt-11-5.sfi` and `ibt-11-5.ddc` bytes, loaded from the non-packaged
  data directory by the patched `h2generic` driver, started firmware build 14
  (week 44, 2021). An inquiry then found a pair of Bluetooth headphones.
- Not yet tested: a cold boot that loads the files from the package, and the
  8265 files.
- The stock `h2generic` driver does not load this firmware. The loader is
  proposed to RenkuOS.
- The native repository builder accepted the new package and the 16 existing
  indexed packages. The existing packages were checked against their published hashes.

SHA-256: `e10ba069c1550295f7e629bef9092e9fb23b7ca0d71cfe006545e95e8e209471`.
