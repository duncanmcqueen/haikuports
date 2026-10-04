#!/usr/bin/env python3
"""Write pseudo-random files, verify on close and again later; log any bad 4 KiB pages.
Runs alongside a build to tell an OS/disk-path problem from a compiler problem."""
import hashlib, os, sys, time
d = os.path.expanduser("~/rust/iotest"); os.makedirs(d, exist_ok=True)
log = open(os.path.expanduser("~/rust/iotest.log"), "a", buffering=1)
SIZE = 48 << 20; PAGE = 4096
def page(seed, i):
    return hashlib.shake_256(f"{seed}:{i}".encode()).digest(PAGE)
def write(path, seed):
    with open(path, "wb") as f:
        for i in range(SIZE // PAGE): f.write(page(seed, i))
def verify(path, seed, when):
    bad = []
    with open(path, "rb") as f:
        for i in range(SIZE // PAGE):
            if f.read(PAGE) != page(seed, i): bad.append(i)
    if bad: log.write(f"{time.strftime('%T')} BAD {when} {os.path.basename(path)} pages={len(bad)} first={bad[:8]}\n")
    return not bad
gen, pending = 0, []
while not os.path.exists(os.path.expanduser("~/rust/iotest.stop")):
    p = f"{d}/f{gen}"; seed = f"{gen}"
    write(p, seed); verify(p, seed, "fresh")
    pending.append((time.time(), p, seed)); gen += 1
    while pending and time.time() - pending[0][0] > 300:
        _, q, s = pending.pop(0); verify(q, s, "aged"); os.remove(q)
    if gen % 20 == 0: log.write(f"{time.strftime('%T')} ok gen={gen}\n")
    time.sleep(20)
