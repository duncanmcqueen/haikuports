# Rust 1.99 on Haiku — execution notes

Companion to `Rust 1.99 on Haiku — build plan.md`. Records what the plan got wrong,
what was verified on the VM (hrev59866+79, x86_64), and the route actually taken.

## Review: corrections to the build plan

| Plan says | Verified state | Check |
| --- | --- | --- |
| Phase 1: `x.py build --stage0 <1.94.1 sysroot>` | No `--stage0` flag. Stage0 is set by `build.rustc` / `build.cargo` in `bootstrap.toml` | `x.py --help`, `config.rs` |
| 1.94.1 can be stage0 for 1.99 | **No.** `check_stage0_version` (`src/bootstrap/src/core/config/config.rs`) accepts only 1.98.x or 1.99.x, for rustc and cargo | Ran on VM: `Unexpected rustc version: 1.94.1, we should use 1.98.x/1.99.0` |
| Stage0 needs `rustc-dev`; assemble from components | Not needed. The installed `rust_bin` (`/boot/system/develop/tools/rust`) works as stage0 directly | 1.95.0 stage1 built with it |
| LLVM must be built in-tree on the Haiku host | Not needed natively. beta6 repo has `llvm22` 22.1.8 and `llvm23` 23.1.0 with static libs and `llvm-config`. `--link-static --system-libs` = `-lbsd -lnetwork -lz` | `llvm-config` on VM |
| `src/haiku` in the source | Does not exist in 1.99.0 | `ls` |
| `pkgman search rust` | `rust_bin` 1.94.1 is installed and served | `pkgman search -i` |

Bundled LLVM per release: 1.95–1.98 = LLVM 22, 1.99 = LLVM 23. `llvm22` and
`llvm23` (and their `_clang`) conflict, so the chain swaps them.

## Route taken

Native chain on the VM: 1.94.1 → 1.95.0 → 1.96.0 → 1.97.0 → 1.98.0 (stage1 rustc +
std + cargo each, system LLVM 22, static) → 1.99.0 `x.py dist` (system LLVM 23,
static). Scripts: `../scripts/chain.sh`, `../scripts/dist-199.sh`,
`../scripts/xpy-retry.sh`, config `../bootstrap-native.toml`.

## Haiku findings

1. **`LIBRARY_PATH` is clobbered by `bootstrap.py`.** On Haiku it is the runtime
   loader path. Under non-login SSH it is unset, so bootstrap sets it to
   `stage0/lib` only and cargo fails: `runtime_loader: Can't open file`.
   Fix: export the default value in every build script.
2. **`std` file locks are unsupported on Haiku** (upstream bug). `File::lock`,
   `lock_shared`, `try_lock`, `try_lock_shared`, `unlock` return `Unsupported`,
   because `target_os = "haiku"` is missing from the `flock` cfg lists. libroot
   has `flock()` and the `libc` crate declares it. Bootstrap panics:
   `try_lock() not supported`. Patch: `../patches/0001-std-haiku-file-locking-via-flock.patch`
   (1.99). `../scripts/patch-std-flock.py` applies it to both the old
   `#[cfg]`-attribute layout (1.95) and the `cfg_select!` layout (1.99).
   Workaround for a 1.94.1 stage0: `x.py --bypass-bootstrap-lock`.
3. **`FileCheck` is not shipped** by the Haiku llvm packages; 1.95 sanity check
   needs it. `llvm-filecheck = "/bin/true"` (tests are not run).
4. **Page-sized data corruption in build outputs.** Three times in ~2 h of
   building, a large output had whole 4 KiB pages of wrong data:
   - `libcc-*.rlib`: rustc ICE `assertion failed: bytes[len] == STR_SENTINEL`
   - `librustc_mir_build-*.rlib`: ld `bad reloc symbol index (0x1ba9dd00 >= 0xfe)`;
     `cmp` against a rebuild: same size, ~53 KB differ, one contiguous run of
     pages from page 883, ~95 % of bytes differ inside each bad page
   - cargo link: ld `out of memory allocating 103079215104 bytes`
   The rebuild is bit-identical across runs, so the compiler is deterministic and
   the damage comes from below it (Haiku file/VM cache or the QEMU disk path).
   An older KDL trace in `vm/haiku-serial.log` is also in `VMCache::Delete`.
   Evidence kept in `~/rust/corrupt-evidence/` on the VM. Mitigation:
   `xpy-retry.sh` detects the signatures, deletes the damaged outputs, retries.
   More seen later: `libcurl_sys-*.rlib` (cargo build, 1.95), and an ICE
   `invalid enum variant tag while decoding Visibility`. Rate: about one in three
   large builds. The `io-integrity.py` tester (48 MB pseudo-random files, verify
   fresh and after 5 min) found **no** bad pages in 160+ files over the same
   period, so plain sequential write/read does not trigger it.
4b. **Kernel-level hang.** In the 1.96 build three rustc teams stopped at zero CPU
   for 35+ min. `ps -a` blocked until they were killed. The dump showed worker
   threads (`librustc_driver…`, `lto cgu.04`) in state `???`, i.e. not a normal
   wait. `kill -9` released them. Mitigation: watchdog in `xpy-retry.sh` (log idle
   10 min and load < 0.3 three times → kill rustc, retry).
4c. **Filesystem write deadlock (needed a VM reset).** At ~8 h uptime, after the
   hang above was killed, a new bootstrap sat in `wait`, then every write to
   `/boot` blocked — even `echo x > /tmp/t1` — and `timeout` could not kill the
   writers (stuck in kernel). SSH logins still worked. `shutdown -r` hung, so the
   VM was reset with QMP `system_reset` (05:27). BFS came back clean; the
   `stage0-1.95.0` toolchain was intact. Serial log saved before reset showed no
   new KDL entry. The monitor now probes a write each poll.
4d. **Root cause of the hangs: low-memory deadlock in the kernel (KDL, 09:38).**
   The 8 GB VM froze fully during the 1.99 stage1 build (0 % CPU, no SSH, GUI
   clock stopped). Alt+SysRq+D via QMP `send-key`, then `threads`, `mutex`,
   `rwlock`, `bt` (dump: `evidence/kdl-2026-10-03-bfs-journal-lowmem-deadlock.txt`):
   - thread 19712 (`grep`) holds `sVnodeLock` (write) in
     `create_new_vnode_and_lock` → `malloc` → `reserve_pages` → "waiting for pages"
   - `low resource manager` → `free_unused_vnodes` → `bfs_put_vnode` →
     `Transaction::Start` → waits on mutex "bfs journal"
   - `page writer` waits on `sVnodeLock` (read)
   - rustc, `lto cgu.*`, Terminal, node, bash: 10 threads on "bfs journal"
   So the threads that free memory wait on locks held by a thread that waits for
   memory. Fix applied: `MEM=12288` in `vm/run-haiku.sh` (plan §7 already asked
   for ~12 GB). After a QEMU restart, re-add SSH: `vm/mon.sh 'hostfwd_add
   tcp:127.0.0.1:2222-:22'`. The page corruption (4) is probably the same
   low-memory path; to be confirmed by the 12 GB run.
4e. **Corruption is not low memory, not RAM, not the plain disk path.** With 12 GB
   (11 GB free) it went on: ~1 event per 30–40 min of build. Tests during builds:
   - `ram-integrity.py` (1.5 GB of hashed pages in user memory, re-hashed every
     minute): 0 bad pages in 30+ rounds → guest RAM is fine.
   - `io-evict.py` (11 GB written, more than the cache can hold, then re-read from
     disk): 0 bad pages → sequential write/evict/read through AHCI is fine.
   - A stage2 `librustc_target-*.rlib` that `rustc_driver` linked against at 13:28
     read back as corrupt at 13:51 → good files go bad at rest.
   - `CARGO_BUILD_PIPELINING=false` did not stop it.
   Still open: the trigger is specific to rustc/cargo file use (mmap of
   `.rlib`/`.rmeta` by many processes, rename/hardlink into place). A Haiku bug
   report needs a reproducer that mimics that pattern.
4f. **The "hangs" were debug_server crash dialogs** (found from the user-saved
   report `~/rustc-92112-debug-03-10-2026-15-19-02.report`). A rustc that ICEs and
   double-panics calls `abort()`; debug_server then suspends the team and waits
   for a user answer, so cargo waits forever. Fix (VM, 15:25):
   `~/config/settings/system/debug_server/settings`:
   `executable_actions { /boot/home/rust/* kill … }` — tested with a cross-built
   `abort()` program: killed at once (exit 149). The report also shows ~85
   read-only file mappings owned by `librustc_driver` (rustc's `memmap2` of
   `.rlib`/`.rmeta`) at the time of the crash, which supports the theory that bad
   data enters through file mappings. Follow-up candidate: a Haiku-only rustc
   patch that reads metadata into memory instead of `mmap`, and a reproducer
   that maps many files from several processes while they are rewritten.
4g. **Root cause narrowed to "map a file right after writing it" (16:00–17:45).**
   - Corrupt `librustc_target-*.rlib`: wrong bytes start exactly 4096 bytes into the
     member `*.cgu.02.rcgu.o` and run in 4 KiB pages of that member; the bad content
     occurs nowhere in the good file. So the object file read wrong when rustc mapped
     it (right after LLVM threads wrote it) to copy it into the archive.
   - `objrepro.c` (threads `write()` a file, `pwrite()` page 0, close; main thread
     `mmap()`s it at once and checks every page; delete; reuse the name): 1 bad file
     in ~4,400 in 20 min (6 procs × 4 threads), 4084 of 4085 pages wrong, only the
     `pwrite()` page right. Linux: 0 in ~12,000. Later runs under heavy contention:
     0 in ~2,250 per variant (25 min) and 0 in ~6,600 for mmap and for read (45 min),
     so the rate is low and load-dependent; the mmap/read comparison is not settled.
   - `fsrepro.c` (multi-process write/rename/O_TRUNC, read or mmap verify of
     published files): 0 in ~17 GB. Swap unused (`vmstat`).
   - **`nofilemmap.c` LD_PRELOAD** (private read-only file `mmap()` → anonymous +
     `pread()`): native 1.99 dist ran 15:25–17:44 with **no corruption** (before: one
     every 20–40 min) and produced rustc/rust-std/rustc-dev tarballs. It then failed
     only on `openssl-sys` (packagefs does not show `openssl3_devel` files; `pkgman`
     reinstall wants a reboot) → `OPENSSL_INCLUDE_DIR`/`OPENSSL_LIB_DIR` to an
     extracted copy in `~/rust/ossl`.
   - Candidate kernel path (not confirmed): `file_cache.cpp` `cache_io()` bypasses the
     cache with `write_to_file()` for I/O ≥ `BYPASS_IO_SIZE` (64 KiB) while
     `low_resource_state(B_KERNEL_RESOURCE_PAGES) != B_NO_LOW_RESOURCE`.
   - Reported (user-reviewed text + `objrepro.c`):
     cross-platform-actions/haiku-builder#4 comment 5974018610.
5. **Do not wrap `x.py` in `timeout`.** It kills python only; the bootstrap
   binary and cargo keep running. With `--bypass-bootstrap-lock` two builds then
   write the same tree.
6. No `ghcr.io/haiku/cross-compiler` image for r1beta6. `x86_64-r1beta5` exists
   (useful for Phase 3).

## Upstream candidates

- rust-lang/rust: Haiku `flock` file locking (finding 2).
- Haiku: page corruption under heavy build I/O (finding 4) — needs a reduced
  reproducer before filing.
