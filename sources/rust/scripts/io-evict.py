#!/usr/bin/env python3
"""Write more data than guest RAM, then verify: the early files must be re-read
from disk, so this tests the disk path (driver/DMA), not just the page cache."""
import hashlib, os, sys, time
d = os.path.expanduser("~/rust/ioev"); os.makedirs(d, exist_ok=True)
log = open(os.path.expanduser("~/rust/ioev.log"), "a", buffering=1)
PAGE = 4096; FILE = 64 << 20; NF = int(sys.argv[1]) if len(sys.argv) > 1 else 224   # 224*64MB = 14 GB
def page(f, i): return hashlib.blake2b(f"{f}:{i}".encode(), digest_size=64).digest() * 64
t = time.time()
for f in range(NF):
    with open(f"{d}/f{f}", "wb") as o:
        for i in range(FILE // PAGE): o.write(page(f, i))
log.write(f"{time.strftime('%T')} wrote {NF} files in {time.time()-t:.0f}s\n")
bad_total = 0
for f in range(NF):
    bad = []
    with open(f"{d}/f{f}", "rb") as o:
        for i in range(FILE // PAGE):
            if o.read(PAGE) != page(f, i): bad.append(i)
    if bad:
        bad_total += len(bad)
        log.write(f"{time.strftime('%T')} BAD file={f} pages={len(bad)} first={bad[:8]}\n")
log.write(f"{time.strftime('%T')} verify done bad_pages={bad_total} in {time.time()-t:.0f}s\n")
for f in range(NF): os.remove(f"{d}/f{f}")
log.write("DONE\n")
