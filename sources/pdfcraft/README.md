# Pdfcraft 0.8.0 for Haiku

Personal experimental port; not an official ArtCraft or HaikuPorts build.
AI assistance was used for the port, tests and packaging.

Install from the personal repository with `pkgman install pdfcraft`.
Open Pdfcraft from Deskbar > Applications, or run `pdfcraft file.pdf`.
The package also provides `pdfcraft-cli`. Rust is not required at runtime.

The native release build passed on Haiku hrev60228 x86_64 with Rust 1.99.
Synthetic PDF tests covered opening, text and image rendering, rotation,
combining, extracting and splitting pages. Native Save As and the native
close control's Save/Cancel prompt passed. An external PDF tool checked the
saved file. See PORT-NOTES.md for results and limitations.

Printing, scanning, OCR models, signing and other optional workflows are
unverified. Optional craft-fonts and MCP are not included. The GUI uses CPU
rendering. No control server starts by default. Modified builds omit ArtCraft
trademark images. The backend exits after save/recovery/settings handling to
avoid the known Haiku Wayland teardown fault.

The package is assembled natively from the tested binaries with package create;
it is not a HaikuPorter recipe build. The vendor field follows the existing
repository convention and does not imply endorsement by the Haiku Project.

## Rebuild

Copy this directory to /boot/home/rust/pdfcraft-port. Keep the patch and notices.

```sh
cd /boot/home/rust/pdfcraft-port
git clone https://github.com/storytold/pdfcraft src
git -C src checkout 9931329b9fae0b05373b4dc3ac7c58541f0891a4
git -C src apply ../patches/pdfcraft-0.8.0-haiku.patch
pkgman install cmake
bash build-native.sh
bash packaging/build-hpkg.sh
```

The build script defaults to its own Cargo target directory. The original
build reused Filmcraft's target directory through CARGO_TARGET_DIR to conserve
disk space. It uses two jobs and the local build-only libnofilemmap.so workaround
at /boot/home/rust/libnofilemmap.so. The workaround is not needed to run the app
and is not packaged. A clean source rebuild has not been performed; git apply
--check passed against the pinned release. Public dependency revisions and the
lockfile are in the source patch. Existing upstream vendored PDF fixes remain.

Package: pdfcraft-0.8.0-1-x86_64.hpkg

SHA-256: 0e66a165f3aa01550598924b91e21507ce754eebc1ea0d204b525f4a7a3724ce
