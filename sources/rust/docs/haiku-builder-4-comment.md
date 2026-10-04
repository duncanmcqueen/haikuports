I am seeing the same problem on Haiku R1/beta6 (hrev59866+79, x86_64). I run it in QEMU with KVM, a SATA disk image, 6 CPUs, and first 8 GB and later 12 GB of memory.

When I build Rust on Haiku, the build breaks about every 20 to 40 minutes. The compiler crashes while reading files it wrote itself (`assertion failed: bytes[len] == STR_SENTINEL`), or the linker says an object file is broken (`bad reloc symbol index`, or it tries to allocate 96 GB). If I rebuild the same thing, it works. So the files are being damaged after they are written.

I compared a broken file with a good copy. The bad part is whole 4 KB pages of wrong data. It starts exactly at the second page of an object file that the compiler had just written and then opened with `mmap()` to copy it into a library. The wrong data does not appear anywhere else in the good file.

I wrote a short C program (`objrepro.c`, attached) that copies what the compiler does:

1. Several threads write files of up to 16 MB with `write()`. Each thread then goes back and rewrites the first page with `pwrite()`.
2. The file is closed, and right away it is opened with `mmap()` and every page is checked.
3. The file is deleted, and the next round reuses the same file name.

With 6 processes running 4 threads each, it found 1 bad file out of about 4,400 in 20 minutes. In that file, every page was wrong except the first one, which is the page that was rewritten last. The same program on Linux found no bad pages in about 12,000 files.

To run it: `objrepro <dir> 6 4 20` (6 processes, 4 threads, 20 minutes). It prints a `BAD` line for each wrong page and a `SUMMARY` line per process.

Things I ruled out:

- **Memory:** I kept 1.5 GB of data in memory and checked it every minute during builds. It never changed.
- **Disk:** I wrote 11 GB, which is more than the cache can hold, and read it back from disk. Nothing was wrong.
- **Swap:** Swap was never used while the errors happened.
- **Normal file reads and writes:** Many processes reading, writing, renaming and rewriting files with plain `read()`/`write()` showed no damage, about 17 GB in 20 minutes.
- **Mapping older files:** Opening other processes' finished files with `mmap()` also showed no damage.

So the problem seems to need a file that was **just written** and is then **opened with `mmap()` right away**.

I made a small `LD_PRELOAD` library. It changes `mmap()` of normal files so that it reads the data with `pread()` instead. With it, the Rust build has run for over 1 hour 40 minutes with no damage and finished making its packages. Without it, the build failed every 20 to 40 minutes.

In `src/system/kernel/cache/file_cache.cpp`, `cache_io()` skips the file cache when memory is low and a write is 64 KB or bigger (`BYPASS_IO_SIZE`). Then part of a new file could be only on disk while other parts sit in the cache that `mmap()` uses. I have not confirmed this yet. I am testing it next with memory pressure, and with writes smaller than 64 KB.
