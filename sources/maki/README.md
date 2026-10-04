# maki 0.5.7 for Haiku — recipe and patchset

`maki` is a terminal AI coding agent. This directory holds the recipe and the
source patches used to build the published `maki-0.5.7-1` package.

- `maki-0.5.7.recipe`
- `patches/maki-0.5.7.patchset` (4 patches)

## Recipe

The recipe builds the Rust binary from the upstream `v0.5.7` source plus 687
vendored dependency sources (`SOURCE_URI_2` … `SOURCE_URI_687`: crates.io crates
and two git dependencies, crossterm and syntect). `BUILD()` builds a cargo
`directory` source from those and runs `cargo build --release --frozen`.

- Requires `rust_bin >= 1.95` (built here with the 1.99.0 toolchain).
- Links the system `libcurl`, `libssl`/`libcrypto`, and `libz`.
- `LIBRARY_PATH` must include `/boot/system/lib`, because cargo prepends its own
  paths for the rustc it spawns and otherwise rustc cannot load `libroot`.
- Produces `maki` and a separate `maki_debuginfo` package.

## Patchset (4 subjects)

1. **Haiku: drop the arboard Wayland backend, stub the 12h clock.**
   `arboard`'s `wayland-data-control` feature does not compile on Haiku, so
   arboard is used without it (clipboard falls back to OSC 52). `maki-ui`'s
   clock uses `newlocale`/`nl_langinfo_l`/`T_FMT`, which the `libc` crate does
   not bind for Haiku, so it defaults to 24-hour time there.
2. **Use monty 0.0.21 from crates.io instead of the git tag.**
3. **Link the system libcurl and OpenSSL on Haiku.**
4. **Read terminal input with crossterm's `use-dev-tty` feature on Haiku.**

## Build requirements

- `rust_bin >= 1.95` (the 1.99.0 package in this repository), `cargo`, `gcc`,
  `pkg_config`, and the `libcurl`/`openssl3`/`zlib` development packages.
- Upstream maki needs `rust-version = "1.99"`, which is why the 1.94.1 toolchain
  cannot build it.

## Runtime notes

- No OS keyring on Haiku; supply API keys through config or environment.
- File watching uses polling (more CPU on large repositories).
- `maki update` (self-update) does not work: there is no Haiku release asset.
