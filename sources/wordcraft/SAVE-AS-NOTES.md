# Native Save As investigation

2026-10-14, Haiku VM hrev60228 x86_64, Rust 1.99.

## Reproduction

In r2, a new document with text opened the native save panel. Entering a filename and clicking Save closed the panel, but created no file and left the document dirty.

A separate native command reproduced the return-value problem:

```sh
filepanel --save --single --kind f --directory /boot/home --name wordcraft-panel-check.docx
```

Clicking Save printed `/boot/home/wordcraft-panel-check.docx` to stdout but returned exit code 1. The rfd adapter discarded all output when the exit status was nonzero. Haiku's filepanel source handles B_SAVE_REQUESTED by printing the selected path and handles B_CANCEL by setting the return code to 1; the save path can therefore coexist with the cancellation status.

## Changes

In the Haiku rfd backend, accept exit code 1 for Save only, provided the output contains a path. Empty output still means cancellation. Other error codes are rejected, and Open keeps its existing status handling.

The frontend now asks egui to repaint after the dialog worker sends its result. This allows the editor to finish saving without further input from the user.

Source: port-crates/rfd/src/backend/haiku.rs and src/apps/wordcraft-haiku/src/main.rs. Exported diffs: patches/rfd.patch and patches/wordcraft-haiku.patch.

## Validation

Passed native build (7m12s) and interactive test. Test process 93419 exited with status 0 and has no matching fault in logs/gui-save-as-syslog.log. Cancel left the document dirty; the next Save As created the exact selected filename with spaces, marked it saved, and preserved its text. A subsequent edit and Save updated the same DOCX.

Test script: scripts/smoke-save-as.py. It uses its own document and native dialog, cancels once, saves to a unique filename containing spaces, checks DOCX contents and clean editor state, then edits and saves again. It waits after clicking Save without sending a GUI control message, so the file must be written without a testing-induced repaint.

Evidence: logs/gui-save-as-summary.log, gui-save-as.jsonl, gui-save-as-stderr.log, gui-save-as-syslog.log; artifacts/gui-save-as-after.png and native-save-as.docx.
