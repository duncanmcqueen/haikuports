#!/usr/bin/env python3
"""Hold 1.5 GB of pseudo-random pages in user memory; re-hash every 60 s.
A changed page means guest RAM corruption (host/KVM side), not a file-cache bug."""
import hashlib, os, time
PAGE = 4096; N = (1536 << 20) // PAGE
log = open(os.path.expanduser("~/rust/ramtest.log"), "a", buffering=1)
buf = bytearray(N * PAGE); sums = []
seed = os.urandom(16)
for i in range(N):
    blk = hashlib.shake_256(seed + i.to_bytes(4, "little")).digest(PAGE)
    buf[i*PAGE:(i+1)*PAGE] = blk
    sums.append(hashlib.blake2b(blk, digest_size=16).digest())
log.write(f"{time.strftime('%T')} filled {N} pages\n")
mv = memoryview(buf); rounds = 0
while not os.path.exists(os.path.expanduser("~/rust/ramtest.stop")):
    time.sleep(60)
    bad = [i for i in range(N) if hashlib.blake2b(mv[i*PAGE:(i+1)*PAGE], digest_size=16).digest() != sums[i]]
    rounds += 1
    if bad:
        log.write(f"{time.strftime('%T')} BAD round={rounds} pages={len(bad)} first={bad[:8]}\n")
        for i in bad: sums[i] = hashlib.blake2b(mv[i*PAGE:(i+1)*PAGE], digest_size=16).digest()
    elif rounds % 30 == 0:
        log.write(f"{time.strftime('%T')} ok round={rounds}\n")
