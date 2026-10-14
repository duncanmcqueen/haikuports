# Wordcraft on Haiku

Native CLI build completed and smoke tests passed, 2026-10-13. Build time: 10 minutes 54 seconds.

- Upstream: https://github.com/storytold/wordcraft
- Source revision: 159b84f54c74e9e82fb3109b758ae7dd6f4e3ab0 (0.6.1).
- Target: x86_64-unknown-haiku, Rust/Cargo 1.99.0.
- Build host: Haiku hrev60228, QEMU VM with 12 GiB RAM.
- Command: `cargo build --release --locked --offline -p wordcraft-cli`, two jobs.
- Dependencies vendored on the Linux client with `cargo vendor --locked --versioned-dirs`.
- Local patch: add Haiku system and user font directories.
- Build uses the existing `/boot/home/rust/libnofilemmap.so` workaround for Haiku file-mapping corruption and exports the default `LIBRARY_PATH`.
- Upstream's referenced craftrules repository could not be read: both the GitHub repository and raw AGENTS.md return not found.

The desktop GUI is a separate port. This build targets the CLI, document conversion, PDF/PNG rendering and headless commands.

## Results

- `--version`: wordcraft-cli 0.6.1.
- TXT → DOCX → text and DOCX → ODT → text preserved the input text, ignoring trailing newline normalization (the extractor adds a blank line).
- DOCX → PDF: successful; PDF text independently checked with pdftotext on the client.
- PNG rendering: 1224 × 1584; inspected visually, both test paragraphs rendered correctly.
- Headless sample editing and DOCX save/reopen: successful, two pages and 364 words.
- Command registry JSON: successful.
- Tests run with LD_PRELOAD unset. The executable does not require the build workaround or an installed Rust toolchain.
- Runtime shared libraries: libroot.so, libnetwork.so, libbsd.so, libgcc_s.so.1.
- Binary SHA256: d4d08a954a565f250b377946ed3fc25a482d6a41b8f20ff175be1f8b203df66e.
- Full build and test output: logs/build-haiku.log and logs/test-haiku.log.
- Test input and output: artifacts/test-output/smoke/.
- VM executable: /boot/home/rust/wordcraft-port/src/target/release/wordcraft-cli.

## Use

Extract artifacts/wordcraft-cli-0.6.1-haiku-x86_64.tar.gz on Haiku. In Terminal:

```sh
cd wordcraft-cli-0.6.1-haiku-x86_64
./wordcraft-cli --version
./wordcraft-cli convert /boot/home/input.docx /boot/home/output.pdf
```

To install for your user:

```sh
mkdir -p /boot/home/config/non-packaged/bin
cp wordcraft-cli /boot/home/config/non-packaged/bin/
```

This is a tested CLI build, not the desktop editor. It was tested on the VM, not on the Xiaomi laptop. Wordcraft is upstream alpha software; these synthetic checks do not establish fidelity for arbitrary real-world documents. No changes were submitted upstream.
