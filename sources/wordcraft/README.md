# Wordcraft 0.6.1 for Haiku

This is a personal experimental port, not an official Wordcraft or HaikuPorts build.
The package contains the r3 software-rendered editor and wordcraft-cli.
Rust is not required to run it. Install it with `pkgman install wordcraft`.
Start Wordcraft from Deskbar > Applications. The CLI command is `wordcraft-cli`.

Typing, native Open, Save As, Cancel, and subsequent Save passed on the existing
Haiku hrev60228 x86_64 VM. Printing, system clipboard integration and persistent
editor settings are not wired into this frontend. Normal Wayland teardown is
unreliable; this application uses the process-exit workaround described in GUI-NOTES.md.
International composition and long-duration stability are not established.

## Package provenance

The first package is version 0.6.1-1. It packages already-built, tested binaries;
it does not claim a fresh HaikuPorter source build. The original GUI executable
has SHA-256 bdc944062deb97e3256564ec89448551a8713611da85a1f2d134d6c0b68e16f7.
Native application resources and 16/32-pixel icons are then added to the packaged
copy. The CLI is copied unchanged. The icon PNGs come from Wordcraft's
`assets/app-icon/hicolor` directory; its ATTRIBUTION.md records their license.
Third-party license texts and notices are included in the installed documentation.

AI assistance was used to develop the port, packaging and these notes.
The repository owner controls review and publication. No upstream submission
is included in this publication.

## Source reconstruction

- Clone https://github.com/storytold/wordcraft at
  159b84f54c74e9e82fb3109b758ae7dd6f4e3ab0 into a directory named `src`.
- Apply patches/wordcraft-haiku.patch with `git apply`. It includes the frontend,
  manifest path overrides, Cargo.lock and Haiku font directories.
- Beside `src`, create `port-crates`. Download the pristine versions below from
  crates.io, extract each into its indicated directory and apply its patch
  with `patch -p1`. The Cargo patch paths refer to these sibling directories.

| Directory / patch | Pristine crate version |
| --- | --- |
| wayland-backend | 0.3.17 |
| wayland-client | 0.31.15 |
| winit | 0.30.13 |
| rfd | 0.17.2 |
| calloop-0.13.0 | 0.13.0 |
| calloop-0.14.5 | 0.14.5 |
| smithay-client-toolkit-0.19.2 | 0.19.2 |
| smithay-client-toolkit-0.20.0 | 0.20.0 |

For port-crates/egui-software, clone
https://github.com/DGriffin91/egui_software_backend at
c70e02d3d95c75a82733deb97e516b13a6c86dc6 and apply patches/egui-software.patch.
This patch also includes its constify workspace member changes.

Use Rust 1.99. On the build host, `cargo vendor --locked ../vendor` from `src`
fetches the locked dependencies, including craft-libs at its pinned Git revision.
Save Cargo's printed source-replacement config in src/.cargo/config.toml and
transfer src, port-crates and vendor to Haiku. On Haiku install the development
packages listed in GUI-NOTES.md. Export the default LIBRARY_PATH and use
`CARGO_BUILD_JOBS=2 CARGO_PROFILE_RELEASE_LTO=false cargo build --release --locked --offline -p wordcraft-haiku`.
The CLI target is `wordcraft-cli`. The actual builds also used the build-only
libnofilemmap.so workaround documented under ../rust; unset LD_PRELOAD at runtime.
These reconstruction instructions have not been run as a new clean source build.

## Packaging

The packaging script is independent of HaikuPorter. It accepts the tested GUI
artifact directory (including its licenses, patches and notes), the CLI binary,
the upstream icon hicolor directory, a new absolute output path and a packager:

```sh
bash packaging/build-hpkg.sh /path/to/gui-r3 /path/to/wordcraft-cli \
  /path/to/src/assets/app-icon/hicolor /boot/home/wordcraft-hpkg \
  'Your Name <you@example.com>'
```

It needs Haiku's package, rc, resattr, mimeset, C++ tools, Python 3 and translation
kit. It creates apps/Wordcraft/Wordcraft, bin/wordcraft-cli, a Deskbar link,
licenses and documentation. Bump the PackageInfo revision for any changed binary.
The vendor field matches this repository's existing vendor and does not imply
endorsement by the Haiku Project.
