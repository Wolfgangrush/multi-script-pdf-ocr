# Legal OCR Reader

A minimalist, **fully offline** macOS app for opening PDFs, running OCR, and saving reduced-size copies. Built by an Indian advocate for day-to-day legal-practice workflow — without sending a single byte to anyone.

Three buttons: **Open · OCR · Save**. That is the whole feature set.

---

## Fully offline. No network. No cloud. No account. No API key.

This app makes **zero network calls**. It has no network entitlement, no API integration, no cloud service, no analytics, no telemetry, no version-check ping. It can run indefinitely on a Mac with the Wi-Fi turned off.

OCR runs entirely on your Mac:
- **English (and 16 other non-Indic languages)** — Apple's on-device Vision framework. Fast.
- **All major Indian languages** — bundled Tesseract 5.5 binary + traineddata, executed locally as a subprocess. The Tesseract binary, its dependent libraries (libleptonica, libarchive, libpng, libjpeg, libtiff, libwebp, libopenjp2, etc.), and the language data files are all packaged inside the app. Nothing is downloaded at runtime. Nothing leaves your Mac.

---

## What it does

- Opens any PDF in a clean PDFKit viewer.
- **OCR** button extracts text from each page using the engine appropriate for the selected language. Result appears in a side panel — selectable, copyable per-page or in bulk.
- **cmd+S** saves a reduced-size copy of the PDF (typically 60–85% smaller). Pages are rasterised at 150 DPI and JPEG-recompressed at quality 0.7.

That is the whole feature set.

## Languages supported (v0.2.0 — all bundled, all offline)

**Apple Vision (fastest, on-device):**
English, French, Italian, German, Spanish, Portuguese (Brazil), Chinese (Simplified + Traditional), Cantonese (Simplified + Traditional), Korean, Japanese, Russian, Ukrainian, Thai, Vietnamese, Arabic.

**Tesseract (bundled, on-device):**
हिन्दी (Hindi), मराठी (Marathi), தமிழ் (Tamil), తెలుగు (Telugu), ಕನ್ನಡ (Kannada), മലയാളം (Malayalam), ગુજરાતી (Gujarati), ਪੰਜਾਬੀ (Punjabi), বাংলা (Bengali), ଓଡ଼ିଆ (Oriya), اردو (Urdu), संस्कृतम् (Sanskrit). Plus mixed-script combinations (`hin+eng`, `mar+eng`) for documents that switch between Devanagari and Latin script line-by-line — common in pleadings, FIRs, and vakalats.

Pick the language from the toolbar drop-down and click **OCR**.

---

## What it does NOT do (and will not)

- Annotations / highlighting / form-filling / signing / page reordering / merging
- Cloud sync, accounts, telemetry, analytics, or any network call of any kind
- Auto-update
- Cloud OCR — no Google, no AWS, no third-party API

If you want any of the above, use a different PDF tool. This app stays small and offline.

---

## Install

1. Download `LegalOCRReader-vX.Y.Z.dmg` from the releases page.
2. Open the DMG; drag *Legal OCR Reader* to your `Applications` folder.
3. **First launch:** right-click the app and choose **Open**. This is required because the app is ad-hoc code-signed (not yet notarised by Apple). Subsequent launches work normally with a double-click.

Requires macOS 13 (Ventura) or newer. Universal binary — runs natively on Apple Silicon and Intel Macs.

App size: ~58 MB on disk (DMG ~30 MB compressed). The Tesseract binary, its 15 dependency libraries, and 14 traineddata files account for nearly all of this. The Swift code itself is under 1 MB.

## Use

1. **Open** — `cmd+O` or click `Open`.
2. **Select language** in the toolbar drop-down. English (Vision) is the default and is the fastest. Indian languages use Tesseract — slower (~2–5 seconds per page on a clean 300-DPI scan) but fully on-device.
3. **OCR** — click `OCR`. Recognised text appears in a side panel on the right. Toggle with `Show Text` / `Hide Text`.
4. **Copy** — each page in the panel has a copy button. The `Copy All` button copies the entire document's text with page-number headers.
5. **Save reduced** — `cmd+S` opens a save panel. Choose a destination; a banner reports the achieved reduction (e.g. *"15.2 MB → 3.6 MB (24% of original)"*).

---

## Privacy

- The app collects nothing.
- Nothing leaves your Mac. The app has no network entitlement and makes no network calls of any kind.
- There is no API key, no account, no third-party service.
- The bundled Tesseract subprocess inherits the app's network-free configuration; it does not phone home either.

That is the entire privacy story.

---

## Build from source

```
git clone https://github.com/Wolfgangrush/legal-ocr-reader---For-Indian-Lawyers.git
cd legal-ocr-reader---For-Indian-Lawyers
brew install tesseract tesseract-lang dylibbundler   # required for build
bash build.sh
```

Produces `~/Downloads/Dmgs/LegalOCRReader-vX.Y.Z.dmg`.

The build script:
1. Builds the Swift package as a universal binary (arm64 + x86_64) in release configuration.
2. Assembles the `.app` bundle, copies the SwiftPM resource bundle, and writes Info.plist.
3. Copies the system-installed Tesseract binary into the bundle, runs `dylibbundler` to copy and re-link all transitive dylib dependencies relative to the bundle, and copies the traineddata files for the bundled languages.
4. Strips extended attributes and ad-hoc code-signs the binaries (nested first, then the app).
5. Builds the DMG via `create-dmg` (if installed) or `hdiutil` (default fallback).

Requires Xcode command-line tools (`xcode-select --install`).

## Tech stack

Swift 5.9 · SwiftUI · PDFKit · Vision · ImageIO · Quartz · Swift Package Manager · Tesseract 5.5 (bundled) · dylibbundler (build-time) · ad-hoc codesign · `hdiutil` DMG. No external Swift dependencies.

---

## Roadmap

- **v0.3** — true searchable PDF output (OCR'd text written into the PDF as an invisible text layer using `CGPDFContext` invisible text mode, so Spotlight and Preview's `cmd+F` find OCR'd content inside the saved file).
- **v0.4** — watch-folder mode: drop a PDF into a designated folder, the app OCRs it automatically with the language you chose previously.
- **v0.5** — automatic script detection: if you select "Auto" the app probes each page's Unicode range and routes Hindi/Marathi pages to Tesseract, English pages to Vision, in the same OCR run.

---

## Contributing

Issues and pull requests welcome. PRs that introduce a network call, telemetry, or any cloud dependency will be closed without merge — the offline-only character of this app is non-negotiable.

## License

MIT. See `LICENSE`.

The bundled Tesseract OCR engine is © 2006 Google Inc. and others, distributed under the Apache License 2.0. Leptonica is © 2001 Leptonica and contributors, distributed under a BSD-2-Clause license. The bundled traineddata files are © 2017 Google Inc. (tessdata) under the Apache License 2.0. Copies of these licenses live in `Contents/Resources/` of the installed app and in the Tesseract project documentation.

---

## Disclaimer

This software is provided as a utility. It is not a substitute for legal judgment. The author is an Indian advocate publishing this as personal open-source work, not in any client-services capacity. **No advocate-client relationship is created by your use of this software.** Nothing in this repository constitutes legal advice. The author and contributors disclaim all liability for any consequence — professional, regulatory, or otherwise — arising from the use of this software.
