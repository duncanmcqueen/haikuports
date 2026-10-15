# Rust 1.99.0 for Haiku

Updated 2026-10-15. This directory contains the native build records, source
patch, bootstrap configuration and binary-package recipe. AI assistance was
used for build investigation, porting and packaging. Upstream licenses apply.

## Source patch

`patches/0001-std-haiku-file-locking-via-flock.patch` enables Haiku in Rust
std's flock implementations of File lock/unlock operations. Without this,
the older bootstrap fails with unsupported file locking.

The fix was merged upstream on 2026-10-12:
https://github.com/rust-lang/rust/pull/164031

Merge commit: 443d6582c141f7228739032c9924ab2a3fd2731d.
The built 1.99.0 source predates that merge, so it needed the local patch.
Do not apply it again to source that already contains the upstream fix.
`scripts/patch-std-flock.py` handles the 1.95–1.99 source layouts.

## Native compiler build

The tested native route was 1.94.1 -> 1.95 -> 1.96 -> 1.97 -> 1.98 -> 1.99.
Each compiler bootstraps the next. The final 1.99 build requires a working
1.98 rustc and cargo as stage0; 1.94.1 cannot bootstrap it directly.

The build used Haiku x86_64, 12 GiB VM memory, system LLVM 22 for the
intermediate steps and LLVM 23 for 1.99. The 1.99 compiler reports LLVM 23.1.0.
It used Rust source commit b940084d7eb6a299eb4bfeb8e34901bc051e7ac4.

`bootstrap-native.toml`, `scripts/chain.sh`, `scripts/dist-199.sh` and
`docs/execution-notes.md` record the configuration and commands. These scripts
are historical, environment-specific build records, not a general unattended
installer. They assume the ~/rust source archives, previous-stage toolchain,
bootstrap-199.toml and helper files have been prepared. The LLVM-switching
scripts install/uninstall packages, and the retry helper can kill compiler
processes/delete damaged outputs. Review and adapt them before use. A clean
build from only this repository has not been validated.

For the final source tree, the core operation was `./x.py dist` with:

- The std file-lock patch for this older source.
- bootstrap.toml pointing rustc/cargo at the built 1.98 toolchain.
- System LLVM 23 with static LLVM linkage.
- System curl_devel and libssh2_devel; LIBSSH2_SYS_USE_PKG_CONFIG=1.
  Bundled libcurl had hung in this environment.
- The default Haiku LIBRARY_PATH exported for non-login SSH builds.
- OpenSSL include/library paths set to an extracted copy because this VM's
  openssl3_devel packagefs view was incomplete.
- The local build-only nofilemmap preload workaround and disabled Cargo build
  pipelining for the observed Haiku file/mapping corruption.

`scripts/nofilemmap.c` is the workaround source; it is not packaged into Rust
or needed to run the installed compiler. The corruption evidence is in docs/.
The bootstrap config sets llvm-filecheck to /bin/true because FileCheck was
not installed. That is not evidence of passing LLVM codegen tests. The full
Rust/LLVM test suites were not run. The rust-src component archive in the
release is not the full compiler source needed for a bootstrap.

## Packaging recipe and hosted artifacts

`rust_bin-1.99.0.recipe` is a HaikuPorter binary-package recipe. It repackages
the native dist archive; it does not compile Rust. Its source archive is live:

https://github.com/duncanmcqueen/rust-on-haiku/releases/tag/1.99.0

- rust-1.99.0-x86_64-unknown-haiku.tar.xz SHA-256:
  b7bf61492da5da972c081e77625e2ea7f9cbbf9c761553b84014be9543fa8006
- rust_bin-1.99.0-1-x86_64.hpkg SHA-256:
  b8af898e46f1252ad6145be58efcae3b02ad5094e6b4ab1a4058f450063e1226

Both local artifact hashes match GitHub's published release asset digests.
The recipe now has that archive checksum and requires lib:libssh2 as well as
libcurl, OpenSSL and zlib. The installed cargo's NEEDED list confirms these
libraries. The recipe is x86_64 only and omits rust-analyzer/rust-demangler,
which were not built. The .recipe.in is a historical template, not the current
recipe. HaikuPorter lint passed on 2026-10-15 for the exact recipe saved here.

The HPKG is hosted as a GitHub Release asset because it exceeds GitHub's
per-file git limit. It is not in the GitHub Pages package index. It can be
downloaded and installed as a local HPKG after checking its hash and package
solver proposal; indexing it in another repository is a separate step.

To package the hosted dist archive, put the recipe in a HaikuPorts tree at
`dev-lang/rust_bin/rust_bin-1.99.0.recipe` and run
`haikuporter rust_bin-1.99.0`. Building the compiler itself is the separate
bootstrap process above; there is no validated source-building HaikuPorter
recipe in this submission.

## Verification

`docs/validate-1.99.0-hrev59866+88.log` records passing compiler/tool version
checks, direct compilation, cargo unit/doc tests, file locking, threads/files,
formatting, clippy, documentation and a serde procedural-macro release build.
The same Rust 1.99 toolchain later built the tested Haiku Wordcraft, Filmcraft
and PDFcraft ports. This is Haiku evidence, not a RenkuOS runtime test.

RenkuOS needs its own install/bootstrap validation before claiming support.
