# Node.js 24.21.0 on Haiku x86_64

Recipe: `nodejs24-24.21.0.recipe`. It uses these patches in order:

1. `patches/nodejs-24.21.0.patchset`: the rebased Node 22 Haiku port, preserving
   original author credits. Bundled OpenSSL and standalone GN changes are omitted;
   the recipe uses shared OpenSSL and Node's GYP build. V8's removed
   `GetFreeMemoryRangesWithin` implementation is omitted too.
2. `patches/nodejs-24.21.0-tls.patch`: use local-dynamic TLS on Haiku. V8's
   local-exec model produced `R_X86_64_TPOFF32` relocations rejected by the linker
   while building `mksnapshot`.
3. `patches/nodejs-24.21.0-ipv6.patch`: remove the guessed `IPV6_TCLASS` value;
   return `UV_ENOTSUP` when the platform does not define that socket option.

The build uses ICU 77 and shared brotli, c-ares, libuv, nghttp2, OpenSSL, and zlib.
It produces runtime, development, and debug packages. Put the recipe and all
three patch files into `net-libs/nodejs/` in a HaikuPorts tree, then run:

```sh
haikuporter --lint nodejs24
haikuporter --get-dependencies -j3 nodejs24
```

## Verification

- Source tarball SHA-256 matches the recipe.
- All three patches apply sequentially to the pristine source.
- The native TLS test linked on Haiku and checked thread-local initialization
  and isolation. The rebuilt V8 `api.o` has dynamic TLS relocations and no
  `R_X86_64_TPOFF32` relocations.
- `mksnapshot` and Node linked, and the three `.hpkg` files were created.
- The extracted runtime package reports `v24.21.0`, ICU `77.1`, and six CPUs
  on the test VM. Intl, GC, four worker threads, and SQLite checks passed.
- An HTTP/2 loopback response was received using system nghttp2 1.63.0. The
  test's server-close callback timed out on both Node 24 and the installed
  Node 22; clean HTTP/2 shutdown is not established by this check.
- The IPv6 traffic-class runtime check was skipped: the VM rejected the IPv6
  bind. The explicit unsupported handling was reviewed and compiled.
- The full upstream test suite was not run.

## Installation

```sh
pkgman refresh DuncanHaikuPackages
pkgman install nodejs24
```

Node 24 conflicts with Node 20 and Node 22. The currently published `pi` package
requires `nodejs22`, as does the local `pi_haiku_runtime` guard. Review the solver
proposal when switching an existing pi installation; this package does not
change those dependencies. General pi installation instructions are at
<https://pi.dev>.
