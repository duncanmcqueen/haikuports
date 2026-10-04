#!/usr/bin/env python3
"""Enable flock()-based File::{lock,lock_shared,try_lock,try_lock_shared,unlock} in std
for Haiku (libroot provides flock). Handles both layouts:
  <=1.97-ish: #[cfg(any(..))] / #[cfg(not(any(..)))] attributes before each fn variant
  1.99:       cfg_select! { any(..) => .., _ => .. } inside one fn
"""
import re, sys
p = sys.argv[1] + "/library/std/src/sys/fs/unix.rs"
s = open(p).read()
if 'flock-haiku' in s:
    print("already patched"); sys.exit(0)
first = s.index('pub fn lock(&self)')
start = s.rfind('#[cfg', 0, first)
if start < 0 or 'cfg_select!' in s[first:first + 200]:
    start = first
u = s.rindex('pub fn unlock(&self)')
end = s.index('\n    }\n', u)
region, n = re.subn(r'\n([ \t]*)target_os = "aix",\n',
                    lambda m: f'\n{m.group(1)}target_os = "aix",\n{m.group(1)}target_os = "haiku", // flock-haiku\n',
                    s[start:end])
if n not in (5, 10):
    sys.exit(f"unexpected cfg list count {n}")
open(p, "w").write(s[:start] + region + s[end:])
print("patched", n)
