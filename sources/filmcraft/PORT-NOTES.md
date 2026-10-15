# Filmcraft on Haiku — 2026-10-14

Filmcraft 0.8.0 now builds and runs on the Haiku x86_64 VM (hrev60228,
Rust 1.99). This is an experimental port. It has not been tested on the Mi Air.
Source: https://github.com/storytold/filmcraft
Base commit: 9ed9650cad4c9b22cb8d32f4a9ba8050cde20a62.

## Changes

- Added `apps/filmcraft-haiku`, an isolated Cargo workspace that reuses the
  existing editor, CPU compositor, media engine and project format.
- Added the egui software renderer and Haiku-compatible Wayland/Winit/RFD
  dependencies from the Wordcraft port. The normal eframe frontend still calls
  the same input, update, drawing and shutdown methods.
- Added native Haiku Open/Save panels, project/media command-line arguments,
  autosave, crash reporting and the upstream optional loopback control server.
- Added audio output through safe SDL2 Rust bindings. Mixer callback panics
  produce silence rather than crossing the callback boundary.
- Added the polling notification-pipe fix reproduced during the Maki work.
- Disabled the ArtCraft wordmark for this modified Haiku build, as its license requires.
- Added save-before-close handling. The software backend also needed to process
  CancelClose before exiting its event loop. The regression test fails with
  the original adapter and passes with the fix; native Quit/Cancel was tested.

Dependency follow-ups:

- Winit f9ac83d88b8fddbfc5d0f04b79b241f33a6bf305 fixes the Haiku build when
  X11 features are enabled: https://github.com/rust-windowing/winit/pull/4762
- Software backend 451c0bab15486c3e23167df993826b83e31ddc79 fixes CancelClose:
  https://github.com/DGriffin91/egui_software_backend/pull/24
- Cargo.toml and Cargo.lock pin the remaining dependencies.

## Verification

The host standalone application passes all-target clippy with `-D warnings`,
format checks, and 10 tests, including mixer panic containment and dirty-project
close handling. The final native release build passes. Full upstream workspace
CI was not run, and no Filmcraft upstream PR has been opened.

Native VM tests passed:

- Native window decorations and a readable editor interface.
- Import and preview of a generated five-second 320x180, 24 fps H.264/AAC clip.
- Playback with the audio clock active, advancing video, and zero reported drops
  during the short test. QEMU audio capture contains the expected 440 Hz tone.
- Razor editing, undo and redo, with the expected clip counts.
- Project save and reopen, including a native Save As panel operated by keyboard.
- One-second software H.264/AAC export: 24 video frames, stereo 48 kHz audio.
  Host FFmpeg decodes it without errors. Input/export first-frame PSNR: 47.11 dB.
  FFmpeg is used only for test fixture generation and output verification.
- Quit with unsaved changes shows Save / Don't Save / Cancel. Cancel keeps the
  app open. Saving the test project then permits a normal quit.
- Launch and audio/video playback with system libraries, without Wordcraft's
  private Wayland library or the build-only LD_PRELOAD workaround.

Evidence is in `logs/` and `test-results/` next to this file. The native copies
are under `/boot/home/rust/filmcraft-port/`. Test media and generated projects are
scratch files and are not added to the upstream source tree.

## Build

On Haiku with Rust 1.99 and the SDL2 development package:

```sh
export LIBRARY_PATH='%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib'
CARGO_BUILD_JOBS=2 cargo build --release --manifest-path apps/filmcraft-haiku/Cargo.toml
```

The VM build additionally uses its existing `/boot/home/rust/libnofilemmap.so`
via LD_PRELOAD to avoid the known Rust/Haiku file-mapping issue. It is not used
at runtime. `build-native.sh` records status and logs for the detached build.

The experimental package is built by `packaging/build-hpkg.sh` from the tested
native executable. It includes the source patch and available dependency license
texts. It is a personal binary package, not a HaikuPorter-built port.

## Install and run

Install the local `filmcraft-0.8.0-1-x86_64.hpkg` with pkgman, or copy it into
`~/config/packages`. Launch Filmcraft from Deskbar → Applications or run
`filmcraft`. It starts with an empty project. `filmcraft --demo` opens the demo;
a `.fcproj` path opens a saved project. No control port is opened by default.

This Filmcraft package has not been published to the personal repository.
Wordcraft 0.6.1-2 is already published there:

```sh
pkgman add-repo https://duncanmcqueen.github.io/haikuports/r1beta6/x86_64
pkgman refresh DuncanHaikuPackages
pkgman install wordcraft
```

## Limits

Rendering and decoding use the CPU. Hardware video acceleration and microphone
capture are not implemented in this frontend. High-resolution/long projects,
all codecs, clipboard integration, and all editor functions have not been tested.

The software backend's existing Haiku process-exit workaround is enabled to avoid
its Wayland teardown race. The editor stops audio and flushes autosave before
that exit; it still skips process destructors. This remains a workaround.

## Package result

`filmcraft-0.8.0-1-x86_64.hpkg` (22,046,369 bytes) was created, installed in
Haiku's home package volume, and launched using its Deskbar Applications link.
Application version resources report Filmcraft 0.8.0 (Haiku experimental).
The installed app's native yellow close button correctly asks about unsaved
changes; Cancel preserves the open project. The installed app was then relaunched
with the saved test video project and no control server, and left open for use.

SHA-256: `5d222821528bcf0d13f903f66db95b9d51b9da19481ed06470fee8a09ea69776`.

Host artifact: `artifacts/filmcraft-0.8.0-1-x86_64.hpkg`.
VM copy: `/boot/home/filmcraft-0.8.0-1-x86_64.hpkg`.
Installed app: `/boot/home/config/apps/Filmcraft/Filmcraft`.
Source patch: `patches/filmcraft-0.8.0-haiku.patch`.
The patch passes `git apply --check --reverse` against the completed source tree.

## Menu layout correction — revision 2

The original header placed File/Edit/etc., mode tabs, and the right toolbar in
one row. At 1100 pixels the toolbar obscured Window and Help. Haiku now places
the application menus in a separate 28-point row above the mode tabs. The
content area moves down with the header; menus remain available when the header
is hidden. Other platforms keep their previous arrangement.

The updated package is `filmcraft-0.8.0-2-x86_64.hpkg`. Revision 1 is retained.

Revision 2 validation: native release build passed (2m55s), host all-target
clippy with `-D warnings` and workspace formatting passed. All nine menu
rectangles are above the toolbar; normal 1100px and minimum 960px layouts were
visually inspected. Help opened correctly at 960px. The revision 2 HPKG upgraded
revision 1 successfully and launched from the installed Deskbar link. The old
user window was left running; the updated window was opened separately.

Revision 2 SHA-256:
`862dbee3ebec464ac3ed25eb52febe50b129da9c5bf3538509d62664b0f78a35`.

## Diagonal line correction — revision 3

The dotted diagonal was caused by icon geometry, rather than the menu layout.
`Pen16::crisp` treated every short curve segment as horizontal or vertical.
Snapping those points onto pixels collapsed speaker arcs and made the moon
outline reverse direction. Egui produced NaN vertices, and the software renderer
turned those invalid vertices into triangles extending toward the origin.

Only genuinely horizontal/vertical segments are now snapped; curves retain their
coordinates. Consecutive duplicate points and duplicate closing endpoints are
removed before tessellation. The icon regression test fails before the fix and
passes after it. A headless render of the complete editor has finite vertices
and no diagonal line. All 11 application tests and all-target clippy pass.

The isolated upstream-source change is `patches/filmcraft-icon-snapping.patch`.
The full port patch includes it. Before/after images and reproduction logs are
in `test-results/diagonal-*` and `logs/diagonal-*`. Revision 3 is the updated HPKG.

Revision 3 native validation passed: release build completed in 3m02s. The
1100px and 960px screenshots have no diagonal artifact. The HPKG upgraded
revision 2 in the home package volume, and its installed Deskbar launcher opened
successfully. The installed window was inspected and left open; previous user
windows were not closed. Existing windows continue to use their older build.

Revision 3 SHA-256:
`2f9733ff69b4a8edd2a801efd962074b35c787cc1c93da449d616186d609404c`.
Host package: `artifacts/filmcraft-0.8.0-3-x86_64.hpkg`.
VM package: `/boot/home/filmcraft-0.8.0-3-x86_64.hpkg`.

## Repository publication — revision 4

Revision 4 packages the same tested source code as revision 3. Its vendor field
follows the repository's existing Haiku Project convention; this does not imply
Haiku endorsement. The package revision and native resource revision are bumped.
No new Rust compilation is claimed for this packaging change. Revision 3's local
package bytes are retained. Sources and build instructions are published under
`sources/filmcraft` on the personal-packages branch of duncanmcqueen/haikuports.
