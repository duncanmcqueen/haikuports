#!/usr/bin/env python3
"""Like io-integrity.py, but read back through mmap right after write()+close,
the way rustc reads .o/.rlib files. Logs bad 4 KiB pages."""
import hashlib, mmap, os, time
d = os.path.expanduser("~/rust/iomm"); os.makedirs(d, exist_ok=True)
log = open(os.path.expanduser("~/rust/iomm.log"), "a", buffering=1)
PAGE = 4096
def page(seed, i): return hashlib.shake_256(f"{seed}:{i}".encode()).digest(PAGE)
gen = 0
while not os.path.exists(os.path.expanduser("~/rust/iomm.stop")):
    n = 256 + (gen * 97) % 3840            # 1..16 MB, varying sizes
    p = f"{d}/f{gen % 4}"; seed = str(gen)
    with open(p + ".tmp", "wb") as f:
        for i in range(n): f.write(page(seed, i))
    os.replace(p + ".tmp", p)                 # cargo/rustc also rename into place
    with open(p, "rb") as f:
        m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        bad = [i for i in range(n) if m[i*PAGE:(i+1)*PAGE] != page(seed, i)]
        m.close()
    if bad: log.write(f"{time.strftime('%T')} BAD mmap gen={gen} pages={len(bad)}/{n} first={bad[:8]}\n")
    gen += 1
    if gen % 200 == 0: log.write(f"{time.strftime('%T')} ok gen={gen}\n")
    time.sleep(2)
