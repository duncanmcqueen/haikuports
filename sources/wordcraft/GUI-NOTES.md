# Wordcraft desktop on Haiku

2026-10-13: experimental desktop frontend built and tested on Haiku hrev60228 x86_64 with Rust 1.99.0. A fresh blank document accepts physical VM keyboard input, displays it, and saves the same text to DOCX. The native yellow Haiku tab is present, and its close button exits successfully.

The original desktop uses eframe/wgpu. Haiku's in-process Wayland layer exposes shared bitmap buffers; the frontend in `src/apps/wordcraft-haiku` instead uses the existing WordApp, egui_software_backend and softbuffer. It does not replace the document engine or editor UI.

## Sources

- Wordcraft: https://github.com/storytold/wordcraft at 159b84f54c74e9e82fb3109b758ae7dd6f4e3ab0.
- egui_software_backend: https://github.com/DGriffin91/egui_software_backend at c70e02d3d95c75a82733deb97e516b13a6c86dc6, MIT OR Apache-2.0; adapted from egui 0.34 to 0.36.
- Wayland behavior checked against https://github.com/X547/wayland (Haiku's wl_display_connect implementation) and https://github.com/X547/wayland-server (shared bitmap surfaces).
- Other crates use the exact versions in src/Cargo.lock; local copies are under port-crates/.

## Local changes

- wayland-backend 0.3.17: Haiku uses the system client and server APIs; skip the unused pure Rust backend and expose an in-process connection helper.
- wayland-client 0.31.15: use the system in-process connection on Haiku rather than looking for a desktop socket.
- calloop 0.13.0 and 0.14.5: omit EventLoop AsFd/AsRawFd on Haiku; create nonblocking notification pipes with separate close-on-exec flags.
- smithay-client-toolkit 0.19.2 and 0.20.0: create close-on-exec pipes without pipe2 on Haiku.
- winit 0.30.13: main-thread detection, notification pipe creation and omit the unavailable EventLoop AsFd/AsRawFd API on Haiku. On Haiku, bind the legacy KDE server-decoration protocol exposed by the installed Wayland server and request native window borders. Treat those borders as server decorations so a second client-side frame is not drawn.
- rfd 0.17.2: native file and message dialogs through /boot/system/bin/filepanel and alert; asynchronous requests use a worker thread.
- egui_software_backend: egui 0.36 texture update batches and monitor command; use Wayland explicitly on Haiku; expose raw input and close callbacks so Wordcraft can handle typing and unsaved changes.
- Wordcraft fonts: scan Haiku font directories (same patch as CLI build).

## VM packages added

wayland, wayland_devel, wayland_server, libxkbcommon, libxkbcommon_devel, xkeyboard_config. Installation log: VM /boot/home/rust/wordcraft-port/gui-packages.log.

## Current scope

Experimental `wordcraft-haiku` frontend with native Open/Save dialogs. System printing, default-file associations, system clipboard integration and persistence of editor settings are not wired into this frontend. File filters and dialog parenting are not supported by the filepanel command. Paths containing newlines cannot be round-tripped through its line-based output.

No upstream submission has been made.

## Build and test commands

- VM build script: scripts/build-software-fast-haiku.sh (`cargo build --release --locked --offline -p wordcraft-haiku`, two jobs, release optimization with LTO disabled, existing build-only mmap workaround).
- Run: `/boot/home/rust/wordcraft-port/src/target/release/wordcraft-haiku --sample`.
- Open a document: append its path.
- `--control-stdio` accepts one JSON request per line on stdin and replies on stdout, using Wordcraft's existing control methods. It opens no listening network port. Requests are limited to 1 MiB.
- Client GUI smoke test: scripts/smoke-gui-client.py; creates a sample, edits, saves, renders a page, resizes, captures the VM display, and quits.
- Dependency patch files: patches/. Source copies: port-crates/.



## Platform probe

A native C client connected with `wl_display_connect(NULL)`, completed a registry round trip and exited successfully. It found wl_shm v1, wl_compositor v4, wl_seat v8, xdg_wm_base v3 and the data-device and text-input interfaces. Full output: logs/wayland-probe.log. This verifies the installed in-process server independently of Rust; the GUI tests below verify the Wordcraft window separately.

## Runtime results and remaining checks

The window rendered the full ribbon and sample document. The command API inserted text, and the egui text-input path inserted a second phrase. The saved DOCX was reopened with wordcraft-cli and contained both phrases. Saving, page rendering and resizing to 960 × 680 succeeded.

Native Open also loaded the selected document. Its completion is asynchronous: the command inspection reply can precede the document change in the same frame, so the test waits for a subsequent inspection. The selection is supplied to the actual filepanel process using Haiku's native `hey ... load file(...)` message. This tests the picker process and result handling; it does not simulate clicking a file in the list.

The software renderer's primitive cache does not invalidate cached page images when a texture's pixels change. The frontend disables that cache for now. With the cache disabled, a fresh blank document displayed physical keyboard input correctly. The test created a blank document, focused its page, sent keyboard events through QEMU, and saved the result. Both the actual VM screenshot and the saved DOCX contain exactly “Haiku keyboard typing works.” The test process (team 89160) exited successfully with no matching fault in the subsequent kernel log. Native Open was then verified visually: the actual VM screenshot changed from the sample page to “Native file dialog opened this document.” See artifacts/gui-native-open.png.

Haiku's in-process Wayland teardown races background window and protocol threads. Moving client cleanup, adding a round trip, and retaining the display were insufficient; traces include client-map access after free and a BLooper unlock assertion. Some runs returned exit status zero while the kernel logged a late background-thread fault.

The final frontend uses the installed libraries. On Haiku only, after the software event loop returns successfully, the backend calls `_exit(0)` before dropping its windowing state or running C++ global destructors. Document saves and the normal unsaved-change close guard happen before this point. The kernel then reclaims the process resources. This is an explicit application shutdown workaround; proper Wayland library teardown remains unresolved. Error paths keep returning errors normally.

The abandoned private Wayland library experiments and their patch are retained under experiments/ for diagnosis and are not part of the final distribution.

Evidence:

- artifacts/gui-live-test.png: actual VM display after edit/save/resize.
- logs/gui-live-test.jsonl: requests and responses.
- artifacts/gui-blank-typing.png and blank-typing.docx: visible and saved physical-keyboard test.
- logs/gui-blank-typing.jsonl and gui-post-typing-syslog.log: input requests and subsequent kernel log.
- logs/gui-shutdown-crashes.log and gui-open-full-syslog.log: initial and late shutdown faults.
- logs/software-build-haiku.log: first executable build (13m48s).
- logs/gui-runtime-stderr.log: runtime diagnostics. xkbcommon reports no Compose file for locale C under SSH; simple text input passes. Dead keys and international composition remain unverified.

Final validation checked exit status and the subsequent kernel log. The final build passed physical typing, DOCX save, native close-button exit (team 91584), and native Open with a visibly refreshed page (team 91694). Neither test team has a fault or debug-server kill in logs/gui-final-syslog.log. These are functional smoke tests, not a long-duration stability guarantee.

Native close-button test: `TEST_NATIVE_CLOSE=1 CLOSE_X=135 CLOSE_Y=24 python3 scripts/smoke-blank-typing.py`. Coordinates apply to the 1280 × 800 VM display and default window position. The script creates its own blank document, saves it, then clicks its close button. It does not close other applications.

Evidence also includes logs/gui-native-close.jsonl, gui-native-close-summary.log, gui-native-open-summary.log and artifacts/gui-native-open.png. Release optimization is enabled with LTO disabled; the final incremental build completed in 6m25s. Development uses LD_PRELOAD only for the compiler's file-mapping workaround; runtime tests unset it.

## r3: native Save As

2026-10-14: fixed discarding a valid save filename when Haiku filepanel exits with code 1. Empty output still cancels. The dialog worker explicitly requests a repaint on completion. Interactive Cancel, Save As to a filename with spaces, saved DOCX contents, clean editor state, and subsequent Save all passed. See SAVE-AS-NOTES.md and scripts/smoke-save-as.py for evidence.
