# maki 0.6.0 for Haiku — recipe and patchset

`maki` is a terminal AI coding agent. This directory holds the recipe, the
source patches, the recipe generator, and the local logging launcher used to
build and run the published `maki-0.6.0-2` package.

- `maki-0.6.0.recipe`
- `patches/maki-0.6.0.patchset` (2 commits)
- `patches/polling-3.11.0.patch` (notification-pipe race fix)
- `maki-launcher` (optional local wrapper; see Runtime notes)
- `gen-recipe.py` (regenerates the recipe from the patched `Cargo.lock`)

## Recipe

The recipe builds the Rust binary from the upstream `v0.6.0` source plus 705
vendored dependency sources (`SOURCE_URI_2` … `SOURCE_URI_706`: crates.io crates
and two git dependencies, crossterm and syntect). `BUILD()` assembles a cargo
`directory` source from those and runs `cargo build --release --frozen`.

- Requires `rust_bin >= 1.95` (built here with the 1.99.0 toolchain); upstream
  maki needs `rust-version = "1.99"`.
- Links the system `libcurl`, `libssl`/`libcrypto`, and `libz`.
- `LIBRARY_PATH` must include `/boot/system/lib`, because cargo prepends its own
  paths for the rustc it spawns and otherwise rustc cannot load `libroot`.
- Produces `maki` and a separate `maki_debuginfo` package.

Regenerate the recipe after a version bump with:

```sh
python3 gen-recipe.py <patched Cargo.lock> > maki-<version>.recipe
```

## Patchset (2 commits)

1. **Haiku: adjust sources for maki 0.6.0.**
   - Drop `arboard`'s `wayland-data-control` feature on Haiku
     (`wayland-backend` does not build); the clipboard falls back to OSC 52.
   - Stub `system_uses_12h` to false on Haiku: the `libc` crate binds neither
     `newlocale` nor `nl_langinfo_l`/`T_FMT` there.
   - Read terminal input with crossterm's `use-dev-tty` backend: mio's poll
     backend stops reporting the tty readable after the first key event.
   - Use crates.io `monty 0.0.23` instead of the git tag so it can be vendored
     offline.
   - Replace `isahc`'s `static-curl` and `native-tls-static` features with the
     dynamic `native-tls` feature, so the link uses the system libcurl/OpenSSL.
     The bundled curl (>= 8.20) hangs on Haiku before the first request.
2. **Haiku: update `Cargo.lock` for maki 0.6.0.**
   `monty`/`monty-macros`/`monty-types` come from crates.io, the static-OpenSSL
   `openssl-src` build is gone, and crossterm's `use-dev-tty` backend adds
   `filedescriptor`.

The previous 0.5.7 patchset had four commits; the same changes are regrouped
here because 0.6.0 moved `isahc` to 2.0 and `monty` to 0.0.23.

## Revision 2: HTTP worker panic

`PATCHES_392` applies the polling patch to its vendored source before Cargo builds.
The recipe generator also emits this entry, so regeneration preserves the fix.

The polling wakeup flag can become visible before its notification byte reaches
the pipe. A concurrent waiter then reads an empty nonblocking pipe and gets
`WouldBlock`. That error terminates isahc's HTTP worker and Maki later panics at
`isahc-2.0.1/src/agent/mod.rs:252`.

The fix accepts `WouldBlock` only when consuming a pipe notification. Other
errors still propagate. On the Mi Air, the standalone concurrent-wakeup test
reported 149 errors before the fix and zero errors in each of three patched runs.

Revision 2 packages the existing fixed VM build under a new package revision.
It is not a fresh full compilation. Its executable is the same one checked on
the Mi Air. A long-running Maki session with the replacement remains to be tested.

## Runtime notes

- No OS keyring on Haiku; supply API keys through config or environment.
- File watching uses polling (more CPU on large repositories).
- `maki update` (self-update) does not work: the upstream installer supports
  only Linux, macOS, and Windows and exits with `unsupported OS: Haiku` because
  no Haiku release asset exists. Use this package instead.
- **Logging path.** maki derives its log directory from the parent of its XDG
  state base. With Haiku's `XDG_STATE_HOME=/boot/home/config/var`, that parent
  is `/boot/home/config` (packagefs, read-only), so maki prints
  `logging disabled, cannot open the log file` on the native path (it still
  runs). `maki-launcher` is a local wrapper that redirects `XDG_STATE_HOME`
  through a writable `.maki-log-state` directory whose `maki` child links back
  to the real state directory; sessions, auth, and the saved model stay put,
  and logs land in `<base>/logs/maki`. A future package could instead correct
  the log derivation in `maki-storage/src/paths.rs` for Haiku.
