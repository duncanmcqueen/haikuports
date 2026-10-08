# Rebuilding these packages

Everything needed to rebuild the packages served from
`https://duncanmcqueen.github.io/haikuports/r1beta6/x86_64` is here or on a
public branch of this repository. Recipes and patchsets are MIT or the upstream
license of the component they build; keep upstream author notices.

The packages use HaikuPorter (`pkgman install haikuporter`) and a HaikuPorts tree
(`~/haikuports`). The tested tree revision is
`a3c47c01ac34878981ed7dfbe52d823e2c8fb503`.

## Node.js 22 (`nodejs22`, `nodejs22_devel`)

- Recipe:
  `haikuports/net-libs/nodejs/nodejs22-22.23.3.recipe`
- Patchset:
  `haikuports/net-libs/nodejs/patches/nodejs-22.23.3.patchset`

They are stored here (exactly the ones that produced the published
`nodejs22-22.23.3-1` package) and are also on the public branch
<https://github.com/duncanmcqueen/haikuports/tree/nodejs22>. Copy them into a
HaikuPorts tree and run `haikuporter nodejs22`, or use
`scripts/rebuild-node-haiku.sh`, which reads the copies in this directory.

The patchset has five parts:

1. **Initial support for Node.js** — Haiku in `common.gypi`, `configure.py`,
   `tools/utils.py`, `node.gypi`, `node.cc`, `node_report.cc`, and the bundled
   OpenSSL gyp files.
2. **Haiku V8 patches** — `V8_OS_HAIKU`, `platform-haiku.cc`, `platform-posix.cc`,
   `sampler.cc`, `stack_trace_posix.cc`, `memory.h`, `export-template.h`.
3. **V8 gyp build for Haiku** — `tools/v8_gypfiles/features.gypi` and `v8.gyp`
   add the Haiku platform sources and `-lexecinfo`.
4. **c-ares compatibility** — `trap-handler.h` and `cares_wrap.h`.
5. **C++20 and pthread_t fixes** — `common_node.gypi` and the V8 abseil
   `sysinfo.cc` thread id (`find_thread`).

`scripts/rebuild-node-haiku.sh` rebuilds Node in an isolated tree and pins the
recipe and patch hashes. Node is built with the system ICU
(`--with-intl=system-icu`) and shared brotli, c-ares, libuv, nghttp2, OpenSSL,
and zlib.

## ICU 77 (`icu77`, `icu77_devel`, `icu77_tools`)

- Recipe: `dev-libs/icu/icu77-77.1.recipe`

Public branch:
<https://github.com/duncanmcqueen/haikuports/tree/icu77>. Copy it into a
HaikuPorts tree and run `haikuporter icu77`. The compiled Node binary loads ICU
77 at runtime; ICU 74 remains available from the official repositories.

## fd (`fd`)

- Recipe: `fd/fd-10.5.0.recipe`
- Helper: `fd/gen-crate-uris.py`

`fd` is not in the beta6 HaikuPorts repository, so this repository supplies it.
Put the recipe in `<tree>/sys-apps/fd/` and run `haikuporter fd`.

## pi (`pi`)

The maintained pi sources are in the owner's private `pi-on-haiku` repository;
the build files are copied here under `pi/`:

- `pi/pack-pi.sh` — build the standard bundled package on a Linux host.
- `pi/pack-pi-haiku.sh` — build the experimental unbundled package on Haiku.
- `pi/scripts/build.sh` — the build logic, pinned to upstream pi commit
  `9fba660cf1caca0ade5bea72269352416e595a19`.
- `pi/0001-coding-agent-support-haiku.patch` — Haiku clipboard and browser
  commands plus fd/rg installation hints.
- `pi/scripts/install-on-haiku.sh`, `smoke-test.mjs`, `check-facets.mjs`,
  `check-node.mjs`, `pack-output.mjs` — install and verification helpers.

`pi/pi-1.0.0.recipe` is a draft. It is not used to build the published package;
it is included so the build can be moved into HaikuPorter once a hosted source
archive exists.

## Haiku agent library (`haiku_agent_library`)

- Source archive: `haiku_agent_library/haiku-agent-library.zip`
- Builder: `haiku_agent_library/build-hpkg.sh`

`build-hpkg.sh` unpacks the archive and runs `package create` to produce
`haiku_agent_library-0.1.0-1-any.hpkg`. The archive contains the `haiku-api`
skill (with the Haiku Book sources), the `haikuports-recipe` skill, and
`AGENTS.md`.

## maki 0.6.0 (`maki`, `maki_debuginfo`)

See `maki/README.md`. The recipe (`maki/maki-0.6.0.recipe`) builds the Rust
binary from upstream `v0.6.0` plus 705 vendored dependency sources, and
`maki/patches/maki-0.6.0.patchset` has two commits (arboard Wayland backend,
12h clock and crossterm terminal input on Haiku; crates.io monty and the system
libcurl/OpenSSL). It needs `rust_bin >= 1.95`.

## Rust 1.99.0 (`rust_bin`)

See `rust/README.md`. The recipe (`rust/rust_bin-1.99.0.recipe`) repackages a
prebuilt tarball and compiles nothing, so it has no patchset. The one source
patch for building the tarball is
`rust/patches/0001-std-haiku-file-locking-via-flock.patch`; the build settings,
the `nofilemmap` workaround, and the pending tasks (checksum, `lib:libssh2`,
`SOURCE_URI`, hosting) are described there. The 1.99.0 `.hpkg` is about 147 MiB
and is too large for the GitHub Pages repository.

## Publishing

`../MAINTAINING.md` describes the repository index generation and the
`publish-haiku-repository.sh` and `build-haiku-repository.sh` scripts. Only one
version of each package belongs in an index; raise the package revision before
replacing a binary.
