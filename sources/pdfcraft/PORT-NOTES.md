# PDFcraft on Haiku

Upstream release: v0.8.0, commit 9931329b9fae0b05373b4dc3ac7c58541f0891a4.
Source: https://github.com/storytold/pdfcraft

This experimental port is in src/apps/pdfcraft-haiku, a standalone Cargo
workspace. It builds a software-rendered GUI and the existing CLI (without the
optional MCP feature). It reuses the tested Haiku backend and pinned dependency
forks from Filmcraft, including polling's notification-pipe fix. PDFcraft's
vendored PDF/renderer patches are retained. The standalone workspace uses the
Haiku Winit fork; the ordinary desktop app retains its upstream vendored Winit.

The UI exposes its existing input/update/drawing methods to the alternate host.
The eframe frontend delegates to the same methods. Native Haiku file panels use
the RFD fork. Native window decorations remain enabled. Quit requests go through
the existing save/discard/cancel flow. Preferences are written atomically; crash
recovery uses an explicit directory. The authenticated loopback control channel
is optional and off by default; its token remains in an owner-only file. No
MCP server starts automatically.

ArtCraft trademark images are not embedded/displayed in the modified Haiku build.
No new fonts or artwork have been added to the upstream source tree.

Host cargo check and standalone all-target clippy with -D warnings pass. The
native release build completed in the Haiku hrev60228 x86_64 VM, Rust 1.99.
It uses two build jobs, the build-only nofilemmap preload workaround, and the
existing Filmcraft target cache to save disk space. The preload is not used
at runtime. CMake 4.4.4 and rhash were installed in the home package volume for
the native cryptography dependency. Existing applications were not stopped.

The three-page synthetic test PDF is outside the upstream tree in test-media/.
It embeds only Inter-Regular (OFL) and includes original vector shapes and a
four-color raster image. Host pdfinfo, pdffonts and pdftotext provide independent
reference results. ReportLab 5.0.1 generated it in a private host venv.

Native application checks are recorded below. No upstream PR has been submitted.

## Native results (2026-10-15)

The native release build passed, including AWS-LC cryptography (no reduced
signing implementation). The final incremental build also passed. On Haiku,
CLI info/text/render/rotate/combine/extract/split passed on the synthetic PDF.
The GUI rendered its text, vector shapes and raster image correctly. Native
Save As saved a filename containing spaces. Clicking the native close control
while dirty displayed the existing save prompt; Cancel preserved the edits,
and Save saved and exited normally. Host Poppler independently confirmed all
three pages and the final 180-degree rotation of page 1. The input SHA-256
remained a281e72681c83c4803592bae25ee58c666e398eae69d3df1e9980ad2c2c173be.
Preferences were written with mode 600 and clean recovery snapshots removed.

Limits: this is a software-rendered experimental port, not a full feature
certification. Printing, scanner integration, OCR model downloads, signatures,
clipboard, optional scripts and non-Latin fallback fonts have not been tested.
No native printing/updater integration is installed by this frontend. Optional
craft-fonts are not included. MCP is excluded from this CLI build. The opt-in
UI control screenshot command is unsupported by the software backend; native
Haiku screenshots were used. The Haiku backend exits the process after the
adapter finishes save/recovery/settings handling to avoid a Wayland teardown
fault. No control endpoint starts during normal use.

The first Save As automation attempt typed an absolute path into Haiku's
filename field, which strips slash characters. The test was repeated with a
normal filename (Pdfcraft GUI saved copy.pdf) and passed. This was a test input
mistake, not a PDF save failure. The stray synthetic output is not packaged.
