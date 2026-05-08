# Changelog

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
