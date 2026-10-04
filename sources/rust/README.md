# Rust 1.99.0 for Haiku — recipe, patches, and build notes

This directory holds everything used to build and package the Rust 1.99.0
toolchain for Haiku x86_64.

- `rust_bin-1.99.0.recipe` — the current recipe (repackages a prebuilt tarball).
- `rust_bin-1.99.0.recipe.in` — recipe template with `@HOST@`, `@SHA256@`, and
  the version placeholders. (It still lists the old rust-analyzer/rust-demangler
  entries; the plain `.recipe` is the current one.)
- `patches/0001-std-haiku-file-locking-via-flock.patch` — the one source patch.
- `scripts/` — build, patch, validation, and reproduction helpers.
- `bootstrap-native.toml` — the bootstrap configuration used for the dist.
- `docs/` — execution notes, lessons learned, the Haiku bug-report text, and a
  KDL capture.

## What the recipe is

`rust_bin-1.99.0.recipe` is a version bump of the existing
`dev-lang/rust_bin/rust_bin-1.94.1.recipe`. Like 1.94.1 it **repackages a
prebuilt tarball** — it compiles nothing and has **no patchset**. Changes from
1.94.1:

- **x86_64 only.** The i686 branch and `SECONDARY_ARCHITECTURES` are gone;
  i686 users keep 1.94.1.
- **Versions:** `cargoVersion 0.100.0`, `rustfmtVersion 1.10.0`,
  `clippyVersion 0.1.99`, taken from the 1.99 source.
- **Removed:** `rust-analyzer` and `rust-demangler` are not in the dist, so they
  are gone from `PROVIDES` and the symlink loop.
- **License:** now lists both MIT and Apache v2; the tarball ships both files.
- **`REQUIRES`:** adds `lib:libcurl`, because cargo now links Haiku's libcurl.

## Still to do before this recipe is final

1. **Checksum.** `CHECKSUM_SHA256` is out of date. It belongs to the tarball
   whose cargo hangs. The fixed tarball now building will have a new SHA-256.
2. **`lib:libssh2`.** Probably needs adding to `REQUIRES` if the new cargo links
   the system libssh2. Confirm from the cargo binary's library list.
3. **`SOURCE_URI`.** It points at a GitHub release that does not exist yet. The
   plan is to host on `dl.rust-on-haiku.com` before any PR; that depends on
   nielx.

## Building the tarball

The recipe needs no patches. Building the prebuilt tarball needs one source
patch and some environment settings.

### Source patch

- `patches/0001-std-haiku-file-locking-via-flock.patch` adds Haiku to std's
  `flock` lists for `File::lock`, `lock_shared`, `try_lock`, `try_lock_shared`,
  and `unlock`. Without it the bootstrap panics with
  `try_lock() not supported`.
- It should go upstream to rust-lang/rust, after which no patching is needed.
- `scripts/patch-std-flock.py` applies the same change to the 1.95–1.99 sources
  (it handles both the older `#[cfg]` layout and the 1.99 `cfg_select!` layout).

### Build-environment settings

- Install `curl_devel` and `libssh2_devel` before the dist, so cargo links
  Haiku's libcurl 8.22 and libssh2. (The bundled libcurl 8.20+ hangs on Haiku —
  a curl-rust bug to report.)
- Point `OPENSSL_INCLUDE_DIR` and `OPENSSL_LIB_DIR` at a copy of the openssl
  files. This works around this VM's broken packagefs view of `openssl3_devel`.
- Export the Haiku default `LIBRARY_PATH`.
- In `bootstrap.toml`: put `rustdoc` in `tools`, and set `src-tarball = false`
  and `llvm-filecheck = "/bin/true"`. The full file is `bootstrap-native.toml`.
- Stage0 is the previous release (the chain's 1.98.0); 1.99's bootstrap refuses
  older stage0 versions.

### The nofilemmap shim

`scripts/nofilemmap.c` is an `LD_PRELOAD` shim that replaces private read-only
`mmap()` of regular files with an anonymous mapping filled by `pread()`. It is a
workaround for a Haiku R1/beta6 file-corruption bug (whole 4 KiB pages of wrong
data after a file is written and immediately mapped). Builds need it today, but
**it is not part of the package.**

The reproducers (`objrepro.c`, `fsrepro.c`) and the I/O checks
(`io-integrity.py`, `io-mmap.py`, `io-evict.py`, `ram-integrity.py`) are the
diagnostics used to isolate the bug. `docs/haiku-builder-4-comment.md` is the
draft Haiku bug report.

## Hosting the package

The `rust_bin-1.99.0-1-x86_64.hpkg` produced by this recipe is about **147 MiB**.
That is over GitHub's 100 MiB per-file push limit, so it **cannot be served from
the GitHub Pages package repository** (`duncanmcqueen.github.io/haikuports`).
It needs a package host without that limit — `dl.rust-on-haiku.com` in the plan
— or must be offered as a GitHub *Release* asset, which is downloadable but not
installable through `pkgman`.

## Toolchain versions

- Rust 1.99.0, x86_64-unknown-haiku. Bundled LLVM: 1.99 uses LLVM 23
  (1.95–1.98 used LLVM 22).
- Node is not involved; this is a `rust_bin` binary package plus its standard
  libraries.
