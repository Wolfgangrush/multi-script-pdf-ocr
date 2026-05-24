# Changelog

## v0.3.1 — 2026-05-25

- **Fixed CPU pegging / overheating / occasional crash on large PDFs.** `PDFOCRService.renderPage` was annotated `@MainActor` in v0.3.0, which meant the bitmap render for every page ran on the UI thread. On high-DPI scans of long PDFs (≥ 50 pages) page.draw could occupy main for 2-5s per page, blocking input + redraw, heating the chassis, and very occasionally tripping the AppKit watchdog into killing the app. The renderer now runs on the `PDFOCRService` actor's executor (off main). PDFKit allows render access from any thread provided no concurrent mutation — the actor already serialises page access, so this is safe.
- **Added thermal breathing room between pages.** A 60ms `Task.sleep` now interleaves between page-OCR iterations. The cumulative cost is ≈ 3s on a 50-page run, but it caps thermal load and lets UI redraw / user input slot in without the loop pinning a CPU core continuously.
- **New `Save with OCR` toolbar button** (and `⌘S` menu entry — Save Reduced moved to `⇧⌘S`). After running OCR, this saves the PDF **uncompressed** (clean copy, no rasterisation, layout preserved) plus a paired `.txt` sidecar with the recognised text page-by-page. Closes the gap where the only persistence path forced compression. Use when you want a searchable record without the size-reduction cost. Disabled until OCR has been run.

## v0.3.0 — 2026-05-13

- **App icon added.** Custom AppIcon.icns (16/32/128/256/512 + @2x retina) generated from a 1024×1024 source and wired via `CFBundleIconFile`. The icon shows a document with an `अ` glyph and OCR magnifier — signalling the multi-script PDF OCR purpose.
- **Close PDF button + ⌘W shortcut.** Toolbar now has an `xmark.circle` button next to the filename. Also surfaced as `File → Close PDF` in the menu bar. Closing clears the document, OCR pages, sidebar, and any banner. Disabled while OCR or compression is in progress.
- **Banner UX overhauled.** Success messages auto-dismiss after 4s. Info and error messages are persistent until the user clicks the close button — fixes the case where a 3-second banner flashed past while the user was looking at Finder for the output file. Banner now carries an icon (✓ / i / ⚠) and outline colour per level (green / blue / orange).
- **Save Reduced shows progress.** The toolbar button now displays a spinner with "Compressing…" while the compressor runs, and is disabled to prevent double-clicks. Compression yields to the run-loop so the spinner renders before PDFKit starts crunching.
- **Friendlier "already optimised" path.** Instead of `Save failed: Already optimised…`, the banner now reads `PDF already well-compressed — no reduction possible. Source is X MB; a re-encoded copy would be Y MB. No file written.` It is shown as info (blue), not error.
- **OCR rendering honours page rotation.** `PDFOCRService.renderPage` previously allocated a bitmap with unrotated mediaBox dimensions — rotated scans (common from phone-captured pages) were rendered into a mis-shaped canvas and OCR'd sideways. Now uses display dimensions.
- **Fixed Apple Vision Thai-fallback bug.** Vision was running with `automaticallyDetectsLanguage = true`, which caused it to fit unsupported Indic scripts onto the closest visually-similar supported script — typically Thai — producing garbage like `สาย / ดิ / อะ` instead of returning nothing for Devanagari glyphs. Vision is now pinned to `en-US` only. Non-Latin glyphs are skipped cleanly. For Devanagari documents (including mixed Marathi + English), users should pick a Tesseract option from the language picker.
- **Renamed to *Multi-Script PDF OCR*** (from *Legal OCR Reader*). Bundle identifier changed to `net.wolfgangrush.MultiScriptOCR`. App is positioned as a generic offline multi-script PDF OCR tool — legal documents are one supported use case among many (government documents, scanned books, research papers, business contracts, historical archives).
- **Compressor rewritten — selective rasteriser.** The v0.2 compressor rasterised every page at 150 DPI / JPEG 0.7, which inflated digital-text PDFs and many low-DPI scans (output ended up larger than input). v0.3 detects whether each page has a real text layer:
  - Pages with text are copied through unchanged (preserves searchability and stays tiny).
  - Image-only / scan pages are rasterised at 110 DPI, JPEG 0.55, honouring page rotation so output displays upright.
  - If the resulting PDF would be ≥ the input size, the app refuses to write and reports "already optimised — no further reduction possible" instead of silently producing a larger copy.
- Banner now reports rasterised vs preserved page counts alongside the size reduction.
- Removed dead `Reduce-File-Size.qfilter` resource (unused since v0.1.1 replaced the Quartz-filter approach).
- Added **Help → Contact Support** menu item that opens a mailto link to `wolfgangrush@gmail.com`.
- Info.plist now carries `NSHumanReadableCopyright` with the support email.

## v0.2.0 — 2026-05-09

- **Bundled Tesseract 5.5 for offline Indian-language OCR.** All 12 major Indian-script traineddata files are now bundled into the app: Hindi, Marathi, Tamil, Telugu, Kannada, Malayalam, Gujarati, Punjabi, Bengali, Oriya, Urdu, Sanskrit. Plus mixed-script combinations (`hin+eng`, `mar+eng`) for documents that switch between Devanagari and Latin script.
- The Tesseract binary, its 15 dependent dylibs (libleptonica, libarchive, libpng, libjpeg, libtiff, libwebp, libopenjp2, etc.), and the traineddata are all packaged inside the `.app`. Path resolution uses `@executable_path/../Frameworks/` so the app is fully self-contained — no Homebrew install required by the user.
- Added a language picker in the toolbar. English continues to use Apple Vision (fast, on-device, native). Selecting any Indian language routes to the bundled Tesseract subprocess.
- Build script now runs `dylibbundler` to relocate transitive dylib deps + ad-hoc signs nested binaries (dylibs, the bundled Tesseract, then the app) before signing the app. Strips extended attributes that codesign rejects.
- App size grew from ~500 KB to ~58 MB (DMG ~30 MB) — almost entirely the Tesseract runtime + traineddata. Swift code remains under 1 MB.
- App sandbox dropped — incompatible with subprocess execution. Network entitlement remains absent. The app is offline-only and now self-contained.

## v0.1.2 — 2026-05-09

- Renamed app to **Legal OCR Reader** (bundle name + DMG volume name).
- **Removed Gemini API integration entirely.** App is now strictly offline. No network entitlement, no API key, no Preferences window, no Keychain storage. Architectural simplification — the app's value proposition is local-only PDF processing for legal-practice workflows where confidentiality and DPDP-compliance considerations make any cloud route inappropriate by default.
- Removed `GeminiOCREngine.swift`, `PreferencesView.swift`, `KeychainStore.swift`, and the network entitlement.
- Removed warning sheets; with no Gemini path, no warning is necessary.
- README rewritten as short user-facing guide.

## v0.1.1 — 2026-05-09

- Removed the v0.1.0 attempt to embed OCR text directly into the PDF as invisible PDFAnnotation overlays. The annotations rendered with opaque backgrounds in PDFKit regardless of clear-colour settings, producing visible black rectangles. OCR results are now displayed in a side panel on the right of the window with per-page sections, individual copy buttons, and a "Copy All" action. The PDF itself is left untouched.
- Replaced the v0.1.0 reduce-size implementation. The previous implementation depended on the `"QuartzFilter"` `CGContext` options key, which is not a public API. The replacement rasterises each page at 150 DPI and JPEG-recompresses at quality 0.7. Reduction is typically 60–85% on scanned bundles and 30–50% on PDFs that were already digital.
- Save operation now uses `NSSavePanel` so the user explicitly authorises the output URL.
- Banner now reports the actual size reduction achieved.

## v0.1.0 — 2026-05-09

- Initial public release.
- PDF viewer (PDFKit).
- OCR via Apple Vision and Gemini 2.5 Flash (Gemini removed in v0.1.2).
- Save reduced PDF.
- Universal binary, sandboxed, ad-hoc code-signed, DMG distribution.
