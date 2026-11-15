# Stillframe

Stillframe captures and annotates screenshots, stitches scrolling content, and records your screen on macOS. It uses AppKit, SwiftUI, ScreenCaptureKit, and Vision. Captures and OCR stay on your Mac.

[![Stillframe’s Scrolling Capture controls beside a stitched trail-guide screenshot](docs/stillframe-hero.png)](docs/stillframe-demo.mp4)

**[Watch the 30-second demo (MP4)](docs/stillframe-demo.mp4)** · An animated walkthrough using native Stillframe screenshots and a sample trail guide.

Choose **Scroll**, select the content, then click **Scroll & Capture** to add each section. Click **Finish** to save the combined screenshot and copy it to the clipboard. See the [30-second demo storyboard](docs/demo-storyboard.md) for the full walkthrough.

- **Scrolling capture** stitches content beyond the visible screen into one image.
- **Screenshots and annotation** let you capture an area, window, or display and mark it up.
- **Local screen recording** captures the main display as an MP4, with trimmed clip and GIF export.

**[Getting started](#build-and-launch)** · Build Stillframe and choose **Scroll** to try the demo workflow.

Requires **macOS 15+** and Xcode with a macOS 15 or newer SDK. The scripts use `/Applications/Xcode.app` when present. Set `DEVELOPER_DIR` to use a different Xcode installation.

## Build and launch

```sh
./build.sh
open Stillframe.app
```

The build assembles and ad-hoc signs a local `Stillframe.app` in this directory. Drag the app to Applications yourself if desired. Rebuilding an ad-hoc signed app may require regranting screen permission.

## Use

- **Area / Window / Screen:** select a region, a window, or the main display. Every completed screenshot is automatically copied to the clipboard as PNG and TIFF, as well as saved in your library. Area selection supports Return for the whole display. Escape cancels interactive capture. Timer offers 3, 5, or 10 seconds to prepare your capture.
- **Settings:** open the gear button or Command–comma. Record your own shortcuts (or use key/modifier selectors), configure capture delay, cursor/shadows, open-editor behavior, default PNG/JPEG export, recording frame rate/resolution/audio, and default background. Apply saves changes locally; unavailable shortcut combinations leave the previous bindings active.
- **Global shortcuts:** Control–Command–Shift–4 captures an area; Control–Command–Shift–3 captures the main display; Control–Command–Shift–5 starts/stops recording; Control–Command–Shift–6 starts scrolling capture or scrolls and captures the next frame; Control–Command–Shift–Return finishes and copies the combined screenshot. All five can be changed in Settings. Option combinations, F1–F20, navigation keys, and punctuation are supported; macOS-reserved shortcuts may be unavailable. Recommended shortcuts can be restored with one button. Older three-shortcut configurations are migrated without replacing your choices. Stillframe stays in the menu bar when its window closes.
- **Import / Paste Image:** open an image with Command–O, or paste an image using Shift–Command–V. Import works without screen permissions.
- **Annotate:** select a tool and drag on the image. Arrow, rectangle, ellipse, pencil, highlight, solid redaction, text and numbered steps are available. Click to place text or a step. Set the annotation text before placing it.
- **Crop:** drag the desired region. Crop flattens existing marks; Undo restores the previous image and editable marks. Undo/Redo use Command–Z / Shift–Command–Z and apply during the current editing session.
- **Backdrop:** toggle padding around your image. The palette menu offers Ocean, Sunset, Graphite, Paper, a custom background image, and padding presets. Each capture keeps its own background and supports Undo/Redo; imported background images are embedded (maximum 2048px edge).
- **Copy Text:** recognize text on-device with Vision and copy it. OCR uses the edited image, respecting redactions.
- **Copy / Export:** copy the rendered image (Shift–Command–C) or save a PNG/JPEG (Command–S). The capture overlay also supports dragging the edited preview into other apps.
- **Pin:** keep a resizable copy above other windows.
- **History:** captures and edits survive relaunch. Search by name and filter images/videos. Right-click to rename, reveal, or delete a capture.
- **Record:** record the main display as H.264 MP4 at up to 3840 × 2160, with 15, 30, or 60 fps capture settings and optional system audio. Stillframe's windows are excluded. Stop from the editor, menu bar, or global shortcut, then play or export the finished video. Quitting while the recorder is busy is blocked to protect its output.

## Scrolling capture

Choose **Scroll**, then drag a rectangle around the scrolling content. Stillframe takes the first frame automatically. Choose **Scroll & Capture** to scroll the selected window down and stitch in the next section. Repeat until you have what you need, then choose **Finish** to save and copy the combined image. **Cancel** discards the session.

To continue a screenshot you just took, choose **Extend with Scrolling** from its capture overlay, **Extend…** in the editor, or the library's right-click menu. New area/fullscreen captures remember their region, so extension reuses it automatically. Older, window, imported or cropped screenshots ask you to select the original region again (Return selects the full display). The original screenshot becomes frame 1. Press **Control–Command–Shift–6** to scroll and capture the next section, and **Control–Command–Shift–Return** to finish and copy. Existing annotations/redactions are flattened into the seed and preserved; decorative backgrounds are excluded from matching. The original library item is retained.

Keep the region/scale unchanged and leave overlapping content visible. Exclude fixed headers, floating controls and scrollbars where possible. Stillframe matches overlapping image rows and rejects duplicate, missing or ambiguous matches. If the window does not respond to automatic scrolling, scroll it down yourself and choose **Add Current Frame**. If needed, enable **Set overlap manually** and specify how much of the new frame was visible before scrolling. Scrolling is downward, with an 80-megapixel output limit.

## Video clips and GIFs

Select a recording in the library. Set **Start** and **End** in seconds, or use the sliders. **Preview clip** plays the selected range; **Export Clip** creates a trimmed MP4, preserving the original. **Original MP4** exports the complete recording.

**Export GIF** creates a looping, silent animated GIF from the same range. Choose 5/10/15 fps and a maximum edge of 480/720/1080px. GIFs support clips up to 30 seconds; select a shorter range for longer recordings. Export shows progress and supports cancellation. Existing destination files are replaced only after a successful export; exporting over the source recording is blocked.

## Screen permissions

The first capture or recording requires **System Settings → Privacy & Security → Screen & System Audio Recording → Stillframe**. Enable access, then quit and reopen Stillframe when macOS requests it. **Scroll & Capture** also needs **Privacy & Security → Accessibility** to send a scroll event. Manual scrolling with **Add Current Frame** works without that permission. No microphone access is needed. Timer capture hides the app while you prepare the screen.

## Local data

`~/Library/Application Support/Stillframe/history.json` stores capture metadata and editable annotations. PNG/MP4 files are alongside it. Files are local and unencrypted. The original screenshot remains available for editing: **redaction removes source pixels in flattened copies/exports, but does not erase the original from your capture library.** Delete the capture to remove its library source. Cropping replaces the library image; the current session can undo it. Undo history is not persisted between launches. `preferences.json` stores settings, including global shortcut bindings and default background assets. Existing capture history remains compatible with 0.1.0.

If `history.json` cannot be read, Stillframe reports the problem and moves the file aside as `history.corrupt-<id>.json` in the same folder before saving anything new, so the original metadata is never overwritten. Library entries always refer to files directly inside this folder.

## Scope

This is a working independent implementation of the core local capture workflow, not full CleanShot parity. Webcam/microphone recording, horizontal stitching, Studio Mode/zoom editing, and cloud hosting/collaboration are not implemented. Recording currently targets the main display; area screenshots use Stillframe’s region picker and window screenshots use the macOS window picker.

## Tests

```sh
./test.sh
```

Extra arguments are passed to `swift test`, for example `./test.sh --filter RegressionTests` or `./test.sh --enable-code-coverage`.

The suite (`Tests/StillframeTests`) covers the non-interactive core:

- **Editing and rendering:** opaque redaction, crop orientation and bounds, all annotation tools, backdrop padding and clamping, per-capture backgrounds, undo/redo across crop and background changes.
- **Library:** history persistence and relaunch, rename, search and filtering, delete (including entries whose file was already removed), corrupt settings or history recovery without data loss, and confinement of library files to the library folder.
- **Clipboard:** every completed capture publishes PNG data, even with a legacy opt-out setting.
- **Shortcuts:** validation, labels, migration of older three-shortcut settings, function keys, punctuation and menu key equivalents.
- **Scrolling capture:** three-frame stitching, duplicate, mismatched, too-small and ambiguous (repeating) frames, and manual overlap.
- **Capture and recording configuration:** `screencapture` arguments for each mode and recording size/frame-rate limits.
- **Video export:** real MP4 trimming and GIF encoding, invalid ranges and GIF settings, destination replacement, source preservation and cancellation.

Live screen capture, recording, global hotkeys and the SwiftUI/AppKit views need macOS permissions and user interaction, so they are not covered by automated tests; check them manually after changing those areas. The clipboard and video tests need the system pasteboard and the H.264 encoder, so run the suite from a logged-in macOS session.

## Continuous integration

`.github/workflows/ci.yml` runs on pushes to `main`, pull requests and manual dispatch, on a GitHub-hosted `macos-15` runner. It runs the test suite with compiler warnings treated as errors, publishes a line-coverage table to the job summary, and builds, verifies and lints the release `Stillframe.app` bundle. Documentation-only changes are skipped, superseded runs are cancelled, and the workflow uses a read-only token with a commit-pinned checkout action. Hosted runners are free for public repositories; on a private repository, macOS minutes count against the plan's Actions quota.

## Troubleshooting

- **Capture or recording produces nothing:** enable Stillframe under **Privacy & Security → Screen & System Audio Recording**, then quit and reopen it. Each ad-hoc rebuild may need the permission again.
- **Scroll & Capture does not scroll:** grant **Privacy & Security → Accessibility**, or scroll yourself and choose **Add Current Frame**.
- **"No reliable overlap" or "ambiguous" while stitching:** scroll a shorter distance, exclude sticky headers, or set the overlap manually.
- **A global shortcut does not register:** another app or macOS owns it; choose a different combination in Settings.
- **Settings or history could not be loaded:** Stillframe starts with defaults; an unreadable history file is kept as `history.corrupt-<id>.json` for manual recovery.

## Credits

Stillframe was inspired by the capture workflows described on the [CleanShot X website](https://cleanshot.com/features). Stillframe uses native Apple APIs.
