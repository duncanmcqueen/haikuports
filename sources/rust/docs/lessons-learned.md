# Rust 1.99 on Haiku R1/beta6 — lessons learned

Oct 3, 2026. From building Rust 1.95–1.99 natively on the beta6 VM (hrev59866+79,
x86_64, QEMU/KVM) and starting a Linux → Haiku cross build. Details and timeline:
`execution-notes.md`. Scripts: `../scripts/`.

## 1. The build plan

- **Stage0 must be the previous release.** 1.99's bootstrap refuses any stage0
  rustc *or* cargo that is not 1.98.x or 1.99.x (`check_stage0_version` in
  `src/bootstrap/src/core/config/config.rs`). With only `rust_bin` 1.94.1 on
  Haiku, the native route is a chain: 1.94.1 → 1.95 → 1.96 → 1.97 → 1.98 → 1.99.
- **`x.py` has no `--stage0` flag.** Set `build.rustc` and `build.cargo` in
  `bootstrap.toml`. The installed `rust_bin` works as stage0 as is; no
  `rustc-dev` needed.
- **Intermediate steps only need stage1.** `x.py build --stage 1 library` plus
  `x.py build --stage 1 cargo`, then copy `build/<host>/stage1` and add the cargo
  binary and a `bin/lib -> ../lib` link. About 35–60 min per step on the VM.
- **No LLVM build on Haiku.** beta6 ships `llvm22` (22.1.8) and `llvm23` (23.1.0)
  with static libs and `llvm-config`. 1.95–1.98 bundle LLVM 22, 1.99 bundles 23.
  Static `--system-libs` are `-lbsd -lnetwork -lz`, which `rust_bin` already needs.
  `llvm22*` and `llvm23*` (incl. `_clang`, `_lld`) conflict: swap them per step.
- **`FileCheck` is not packaged.** Bootstrap sanity checks want it; set
  `llvm-filecheck = "/bin/true"` when tests are not run.
- **`src/haiku` does not exist** in the source tarball.
- No `ghcr.io/haiku/cross-compiler` image for r1beta6; `x86_64-r1beta5` exists
  and its gcc 13.3 matches beta6.

## 2. Haiku-specific build fixes

- **`LIBRARY_PATH` is the runtime loader path on Haiku.** Under non-login SSH it
  is empty; `bootstrap.py` then sets it to the stage0 `lib` only and every binary
  fails with `runtime_loader: Can't open file`. Export the Haiku default first:
  `%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib`.
- **`std` file locking is missing for Haiku (upstream bug).** `File::lock`,
  `lock_shared`, `try_lock`, `try_lock_shared`, `unlock` return `Unsupported`
  because `target_os = "haiku"` is not in the `flock` cfg lists; libroot has
  `flock()` and the `libc` crate declares it. Bootstrap panics with
  `try_lock() not supported`. Patch: `../patches/0001-std-haiku-file-locking-via-flock.patch`;
  `patch-std-flock.py` handles the old `#[cfg]` layout (≤1.97, 10 lists) and the
  `cfg_select!` layout (1.98+, 5 lists). With a 1.94.1 stage0 use
  `x.py --bypass-bootstrap-lock`; drop it once stage0 has the patch.
- **packagefs can stop showing a package's files.** `openssl3_devel` was
  "installed" but `develop/headers/openssl` and `develop/lib/libssl.so` gave
  "No such file". `package extract` of the `.hpkg` worked, and a `pkgman`
  reinstall wanted a reboot. Workaround: extract to `~/rust/ossl` and set
  `OPENSSL_INCLUDE_DIR`/`OPENSSL_LIB_DIR`.
- **rustdoc is not built when `build.tools` is set** unless the list contains
  `"rustdoc"`. Without it `cargo test` (doctests) and `cargo doc` fail.
- **`[dist] src-tarball = false`.** Otherwise `x.py dist` ends with the full
  `rustc-<ver>-src` tarball (all vendored crates, slow single-thread xz).
- **Set the final config and environment before the first dist.** Changing the
  tools list or adding environment variables made cargo rebuild `std` and the whole
  compiler (~50 min each time).
- **cargo ≥ 1.97 hangs at `Updating crates.io index` when it uses its vendored
  libcurl.** Bisected with the chain's cargos: 1.95 (curl-sys 0.4.83, curl 8.15.0)
  and 1.96 (0.4.87, curl 8.19.0) fetch fine; 1.97 (0.4.88, curl 8.20.0), 1.98 and
  1.99 (0.4.90, curl 8.21.0) hang. Plain `curl` works and the HaikuPorts libcurl is
  8.22.0, so the cause is how `curl-sys`'s generic `build.rs` configures libcurl
  ≥ 8.20 for Haiku (it has no Haiku section) — an upstream curl-rust bug. Fix for
  the package: install `curl_devel` before building cargo, so curl-sys links the
  system libcurl; the recipe then needs `lib:libcurl`.
- Tool versions for the recipe come from `src/tools/{cargo,rustfmt,clippy}/Cargo.toml`
  (1.99: cargo 0.100.0, rustfmt 1.10.0, clippy 0.1.99). On the stable channel the
  dist file names all say `1.99.0`.
- The dist has no `rust-analyzer` and no `rust-demangler`; drop them from the
  recipe's `PROVIDES` and symlink loop. The tarball ships `LICENSE-MIT` and
  `LICENSE-APACHE`, so the recipe's `LICENSE` should list both.

## 3. The beta6 data-corruption bug

**Symptom.** Large build outputs get whole 4 KiB pages of wrong data. rustc ICEs
(`bytes[len] == STR_SENTINEL`, `invalid enum variant tag while decoding`), GNU ld
errors (`bad reloc symbol index`, `out of memory allocating 103079215104 bytes`).
About one event per 20–40 min of building. The build is deterministic: a rebuild
gives a correct file. Same bug reported independently:
cross-platform-actions/haiku-builder#4 (our comment: 5974018610).

**What it is.** In a corrupt `.rlib` the wrong bytes start exactly 4096 bytes
into a `*.rcgu.o` member and are page-aligned to that object file. The object read
wrong when rustc mapped it — right after LLVM threads wrote it — to copy it into
the archive. `objrepro.c` reproduces it without Rust: threads `write()` a file,
`pwrite()` page 0, close; the main thread `mmap()`s it at once → 1 bad file in
~4,400, 4084/4085 pages wrong, only the back-patched page right. Linux: 0.

**What it is not.** Guest RAM (1.5 GB hashed, 0 changes), the disk path (11 GB
written past the cache and read back, 0), swap (never used), qcow2 (the other
report converts to raw), plain multi-process `read()`/`write()`/`rename()`
(17 GB, 0), mmap of older files (0), cargo pipelining (turning it off did not help),
low memory alone (it went on with 11 GB free).

**Workaround that works.** `nofilemmap.c` as `LD_PRELOAD` turns private read-only
`mmap()` of regular files into an anonymous mapping filled by `pread()`. With it,
a native 1.99 dist ran 2 h+ with no corruption. Others got through with
`CARGO_BUILD_JOBS=1` (fewer simultaneous write-then-map events).

**Suspect code (not confirmed).** `src/system/kernel/cache/file_cache.cpp`,
`cache_io()`: writes ≥ `BYPASS_IO_SIZE` (64 KiB) go straight to disk with
`write_to_file()` while `low_resource_state(B_KERNEL_RESOURCE_PAGES)` is not
`B_NO_LOW_RESOURCE`.

**For the shipped toolchain.** Users who build large crates will hit the same
ICEs. Candidates: a Haiku-only rustc patch that reads `.rlib`/`.rmeta`/objects
instead of mapping them, and a kernel fix upstream.

**Retry logic that helped before the workaround** (`xpy-retry.sh`): match the
corruption signatures; delete only the named `.rlib` (cargo rebuilds a missing
output); for metadata ICEs, take the crate name from the `#N [query]` lines; wipe a
whole tree only when the failing `could not compile` block names it; never wipe all
stage trees blindly.

## 4. Other Haiku kernel/system behaviour

- **Low-memory deadlock at 8 GB.** KDL showed: a thread holding `sVnodeLock`
  (write) in `create_new_vnode_and_lock` → `malloc` → `reserve_pages` waits for
  pages; the low resource manager waits for the "bfs journal" mutex
  (`free_unused_vnodes` → `bfs_put_vnode` → `Transaction::Start`); the page writer
  waits for `sVnodeLock`. First signs: rustc threads in state `???` in `ps -a`,
  `ps -a` itself blocking, then every write to `/boot` hanging. Fix: `MEM=12288`.
- **Crash dialogs look like hangs.** A rustc that double-panics calls `abort()`;
  debug_server suspends it until someone answers the dialog. For build trees set
  `~/config/settings/system/debug_server/settings`:
  `executable_actions { /boot/home/rust/* kill … }` (tested: killed at once).
- `vmstat` shows swap use (`free swap space` vs `max swap space`).
- Haiku names mmap areas after the image that created them; a debug report's
  area list shows how many files a process had mapped.

## 5. Running the VM and long jobs

- **Start QEMU outside the agent session** or it dies with the session:
  `systemd-run --user --unit=haiku-vm --collect --working-directory=$PWD/vm -E DISPLAY -E WAYLAND_DISPLAY -E XDG_RUNTIME_DIR ./run-haiku.sh`.
  `run-haiku.sh` has no SSH forward; after each start:
  `vm/mon.sh 'hostfwd_add tcp:127.0.0.1:2222-:22'`.
- **Frozen VM:** QMP `send-key` alt+sysrq+d enters KDL; output goes to
  `vm/haiku-serial.log`. Useful: `threads`, `mutex <addr>`, `rwlock <addr>`,
  `bt <id>`; press space to page. `system_reset` keeps the QEMU process and its
  forwards; BFS replayed its journal cleanly every time.
- **Never wrap a build in `timeout`.** It kills only the top process; bootstrap,
  cargo and rustc keep writing to the tree. With the build lock bypassed, two
  builds then corrupt each other.
- **A hard power-off leaves fresh-looking but partial `.rlib`s.** Wipe the stage
  tree that was being written before resuming.
- **Haiku `ps` columns:** `<command…> <id> <threads> <gid> <uid>` — take the PID
  as `$(NF-3)`; a "first number" parser picks up numeric arguments.
- **bash reads scripts incrementally.** Do not overwrite a running script; a
  sourced helper is fixed for that run (restart to pick up changes).
- Push files with `vm/vmpush.sh`; give every `vmssh` call `</dev/null` when it
  starts background work, or SSH waits for the child.
- Poll status files every 10–20 min; watch for "SSH failed twice" and a write
  probe (`echo x > /tmp/wprobe`) — a working SSH login does not mean writes work.

## 6. Linux → Haiku cross build

- **Toolchain:** copy `/tools/cross-tools-x86_64` out of the r1beta5 image; gcc is
  relocatable (sysroot = `<prefix>/sysroot`).
- **Sysroot from the beta6 VM:** tar `/boot/system/{develop/headers,develop/lib,lib}`
  (skip LLVM/clang/lld). packagefs files are read-only: `chmod -R u+w` the copy.
  Add `develop/lib/libstdc++.so -> ../../lib/libstdc++.so.6`; take
  `openssl3_devel` from `package extract`.
- **Check the toolchain first:** a C program linked with `-lssl -lcrypto` and a
  C++ program both ran on beta6.
- **The build-side LLVM must be in-tree.** `rustc_llvm/build.rs` turns the build
  host's `llvm-config` paths into target paths by replacing the triple; with
  `/usr/bin/llvm-config` it passed `-I/usr/include` to the Haiku g++ and failed in
  `stdlib.h` (`_ALIGNED_BY_ARG`).
- **After switching to the in-tree LLVM**, a stale stamp made bootstrap call a
  missing `build/x86_64-unknown-linux-gnu/llvm/bin/llvm-config`. Build it
  explicitly first:
  `x.py build src/llvm-project --host x86_64-unknown-linux-gnu --target x86_64-unknown-linux-gnu`.
- **Host memory:** with the 12 GB VM running, `-j8` LLVM drove host swap to 29 of
  31 GB and the guest crawled (QEMU RSS 354 MB). Run the cross build with the VM
  stopped or idle, or at `-j4`. A unit can be paused with
  `systemctl --user kill -s SIGSTOP <unit>`.
- Keep the 30 GB tree outside the workspace (indexers) and outside `/tmp` (tmpfs).
