# Filmcraft 0.8.0 for Haiku

This is a personal experimental port. It is not an official Filmcraft or
HaikuPorts build. AI assistance was used for the port, tests and packaging.

Install it on Haiku x86_64 with the personal repository enabled:

```sh
pkgman refresh DuncanHaikuPackages
pkgman install filmcraft
```

Open Filmcraft from Deskbar > Applications, or run `filmcraft` in Terminal.
Rust is not required to run it. The package manager installs the runtime
libraries. The program starts with an empty project. `filmcraft --demo` opens
the demo. A `.fcproj` argument opens a saved project.

## What was tested

On Haiku hrev60228 x86_64, with Rust 1.99 for the build:

- Import, video preview and audio playback with a short 320x180 H.264/AAC clip.
- Razor editing, undo and redo.
- Project saving and reopening, including the native Save As panel.
- A one-second H.264/AAC export, checked with external FFmpeg tools.
- Save-before-close and Cancel with both menu Quit and Haiku's close button.
- Separate menu and toolbar rows at 1100px and 960px window widths.
- Correct speaker/moon icon drawing, with no dotted diagonal line.

The application uses CPU rendering and decoding. Hardware acceleration and
microphone capture are not implemented in this frontend. Large projects,
other codecs, clipboard integration and long sessions need more testing.
It uses the existing Haiku process-exit workaround after saving and stopping
audio, because ordinary Wayland teardown remains unreliable.

## Package provenance

The published package is `filmcraft-0.8.0-4-x86_64.hpkg`. It contains the same
compiled Rust code tested in revision 3. Revision 4 changes the package vendor
to the repository convention and raises the package/application resource
revision. This is a native `package create` build from tested binaries, not a
HaikuPorter source build. The vendor field does not imply Haiku endorsement.
Native resources identify the application. A Deskbar link and `filmcraft`
command launch it. Licenses, notices, the source patch and build notes ship
with the package. Modified builds do not display the ArtCraft wordmark.

See `PORT-NOTES.md` for the full test record. `verification/` has the failing
icon regression before the fix, passing tests after it, clippy results, and
selected media/save checks. The test fixture was generated locally; it is not
bundled. FFmpeg is used only as an external test tool.

## Source reconstruction

Upstream: https://github.com/storytold/filmcraft

Base commit: `9ed9650cad4c9b22cb8d32f4a9ba8050cde20a62`.

Copy this directory to `/boot/home/rust/filmcraft-port`, then run:

```sh
cd /boot/home/rust/filmcraft-port
git clone https://github.com/storytold/filmcraft src
git -C src checkout 9ed9650cad4c9b22cb8d32f4a9ba8050cde20a62
cd src
git apply ../patches/filmcraft-0.8.0-haiku.patch
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
CARGO_BUILD_JOBS=2 cargo build --release --locked --manifest-path apps/filmcraft-haiku/Cargo.toml
cd ..
bash packaging/build-hpkg.sh
```

Build requirements include Rust/Cargo 1.99, native compiler/linker tools,
pkg-config, SDL2 development files and the Haiku package/resource tools.
Cargo downloads dependencies. The patch contains the standalone frontend,
its Cargo.lock, the local polling source/fix and pinned public dependency forks.
The separate `Cargo.lock` file here is a copy for reference. The ordinary
Filmcraft eframe frontend delegates to the same editor methods.

The test VM additionally used the build-only `libnofilemmap.so` workaround.
Its source and build command are in `../rust/scripts/nofilemmap.c` in this
repository. Set `LD_PRELOAD=/boot/home/rust/libnofilemmap.so` for the Cargo build
if using that workaround; unset it before running Filmcraft. `build-native.sh`
records the exact detached build used on the VM. A fresh build from only these
published files has not been tested end to end.

`patches/filmcraft-icon-snapping.patch` is the small upstream icon fix.
`patches/software-backend-cancel-close.patch` records the renderer follow-up;
Cargo already pins the commit that includes it. Do not apply the small patches
again after applying the full port patch.
