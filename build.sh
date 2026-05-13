#!/usr/bin/env bash
# build.sh — produces Multi-Script PDF OCR.app + DMG with Tesseract bundled
# Usage: bash build.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
DMG_OUT_DIR="$HOME/Downloads/Dmgs"
APP_NAME="OCRReader"
APP_DISPLAY_NAME="Multi-Script PDF OCR"
DMG_VOLNAME="Multi-Script PDF OCR"
VERSION="0.3.0"
DMG_NAME="MultiScriptPDF-OCR-v${VERSION}.dmg"
BUNDLE_ID="net.wolfgangrush.MultiScriptOCR"
SUPPORT_EMAIL="wolfgangrush@gmail.com"

# Indian-language traineddata files we bundle. Keep this list in sync with
# OCRLanguage cases in Sources/OCRReader/OCR/OCREngine.swift.
LANG_FILES=(eng osd hin mar tam tel kan mal guj pan ben ori urd san)

echo "──────────────────────────────────────"
echo " ${APP_DISPLAY_NAME} build · v${VERSION}"
echo " Source : $PROJECT_ROOT"
echo " Output : $DMG_OUT_DIR/$DMG_NAME"
echo "──────────────────────────────────────"

mkdir -p "$BUILD_DIR" "$DMG_OUT_DIR"

# ---- 1. Swift build (universal release) -----------------------------------
echo "[1/6] Building Swift package (release, universal)…"
cd "$PROJECT_ROOT"
swift build --configuration release --arch arm64 --arch x86_64 2>&1 | tail -5

EXECUTABLE="$PROJECT_ROOT/.build/apple/Products/Release/$APP_NAME"
RESOURCE_BUNDLE_DIR="$PROJECT_ROOT/.build/apple/Products/Release"
if [[ ! -x "$EXECUTABLE" ]]; then
    BIN_PATH="$(swift build --configuration release --show-bin-path)"
    EXECUTABLE="$BIN_PATH/$APP_NAME"
    RESOURCE_BUNDLE_DIR="$BIN_PATH"
fi
[[ -x "$EXECUTABLE" ]] || { echo "❌ Built executable not found"; exit 1; }

# ---- 2. Assemble .app bundle ----------------------------------------------
echo "[2/6] Assembling .app bundle…"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Frameworks"
mkdir -p "$APP_DIR/Contents/Resources/tessdata"

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$APP_NAME"

# App icon — copy the prebuilt .icns into the bundle.
ICON_SRC="$PROJECT_ROOT/Resources/AppIcon.icns"
if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "  ⚠ AppIcon.icns not found at $ICON_SRC"
fi

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 Wolfgang Rush. Support: ${SUPPORT_EMAIL}</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>PDF Document</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array><string>com.adobe.pdf</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# ---- 3. Bundle Tesseract binary + dylibs + traineddata --------------------
echo "[3/6] Bundling Tesseract binary, dylibs, and traineddata…"

TESSERACT_BIN="$(which tesseract)"
[[ -n "$TESSERACT_BIN" && -x "$TESSERACT_BIN" ]] || {
    echo "❌ tesseract not found in PATH. Run: brew install tesseract tesseract-lang"
    exit 1
}

TESSDATA_SRC="$(brew --prefix tesseract-lang 2>/dev/null)/share/tessdata"
TESSDATA_CORE="$(brew --prefix tesseract 2>/dev/null)/share/tessdata"  # eng + osd live here
[[ -d "$TESSDATA_SRC" ]] || {
    echo "❌ tessdata-lang directory not found at $TESSDATA_SRC. Run: brew install tesseract-lang"
    exit 1
}

# Copy binary
cp "$TESSERACT_BIN" "$APP_DIR/Contents/MacOS/tesseract"
chmod +x "$APP_DIR/Contents/MacOS/tesseract"

# Run dylibbundler — bundles all transitive non-system dylibs into Frameworks/
# and rewrites paths in the binary + each dylib so they resolve at runtime
# via @executable_path/../Frameworks/ relative to the .app's MacOS dir.
if ! command -v dylibbundler >/dev/null 2>&1; then
    echo "❌ dylibbundler not installed. Run: brew install dylibbundler"
    exit 1
fi

echo "  → running dylibbundler (this scans transitive dylib deps)…"
dylibbundler \
    --overwrite-files \
    --bundle-deps \
    --create-dir \
    --fix-file "$APP_DIR/Contents/MacOS/tesseract" \
    --dest-dir "$APP_DIR/Contents/Frameworks/" \
    --install-path "@executable_path/../Frameworks/" \
    2>&1 | tail -5

# Copy traineddata for the languages we support. eng + osd live in the
# core `tesseract` formula; everything else lives in `tesseract-lang`.
echo "  → copying traineddata for: ${LANG_FILES[*]}"
for lang in "${LANG_FILES[@]}"; do
    src1="$TESSDATA_SRC/${lang}.traineddata"
    src2="$TESSDATA_CORE/${lang}.traineddata"
    if [[ -f "$src1" ]]; then
        cp "$src1" "$APP_DIR/Contents/Resources/tessdata/"
    elif [[ -f "$src2" ]]; then
        cp "$src2" "$APP_DIR/Contents/Resources/tessdata/"
    else
        echo "  ⚠ ${lang}.traineddata not found in either tessdata directory"
    fi
done

# Quick sanity check: bundled tesseract reports its languages
TESSDATA_CHECK="$APP_DIR/Contents/Resources/tessdata"
echo "  → sanity check: bundled tesseract languages…"
TESSDATA_PREFIX="$TESSDATA_CHECK" "$APP_DIR/Contents/MacOS/tesseract" \
    --tessdata-dir "$TESSDATA_CHECK" --list-langs 2>&1 | head -20 || echo "  ⚠ tesseract sanity check failed"

# ---- 4. Codesign ----------------------------------------------------------
# If DEVELOPER_ID_IDENTITY env var is set (e.g. "Developer ID Application: Name (TEAMID)"),
# we use it for hardened-runtime signing in preparation for notarisation.
# Otherwise fall back to ad-hoc.
xattr -cr "$APP_DIR" 2>/dev/null || true

if [[ -n "${DEVELOPER_ID_IDENTITY:-}" ]]; then
    echo "[4/6] Code-signing with Developer ID (hardened runtime)…"
    SIGN_IDENTITY="$DEVELOPER_ID_IDENTITY"
    SIGN_FLAGS=(--force --options runtime --timestamp)

    # Sign nested binaries first (dylibs, then tesseract, then the app itself)
    find "$APP_DIR/Contents/Frameworks" -name "*.dylib" -exec \
        codesign "${SIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" {} \; 2>&1 | tail -3
    codesign "${SIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" \
        "$APP_DIR/Contents/MacOS/tesseract" 2>&1 | tail -3
    codesign "${SIGN_FLAGS[@]}" --deep --sign "$SIGN_IDENTITY" \
        --entitlements "$PROJECT_ROOT/entitlements.plist" \
        "$APP_DIR" 2>&1 | tail -3
else
    echo "[4/6] Code-signing (ad-hoc, deep)…"
    find "$APP_DIR/Contents/Frameworks" -name "*.dylib" -exec \
        codesign --force --sign - --timestamp=none {} \; 2>/dev/null || true
    codesign --force --sign - --timestamp=none "$APP_DIR/Contents/MacOS/tesseract" 2>/dev/null || true
    codesign --force --deep --sign - \
        --entitlements "$PROJECT_ROOT/entitlements.plist" \
        "$APP_DIR" 2>&1 | tail -3 || echo "⚠ Codesign warnings; first launch needs right-click → Open"
fi

# ---- 5. Create DMG --------------------------------------------------------
echo "[5/6] Creating DMG…"
DMG_PATH="$DMG_OUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
        --volname "$DMG_VOLNAME" \
        --window-size 500 350 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 130 150 \
        --app-drop-link 370 150 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_DIR" 2>&1 | tail -5 || {
        echo "  ⚠ create-dmg failed; falling back to hdiutil…"
        hdiutil create -volname "$DMG_VOLNAME" -srcfolder "$APP_DIR" \
            -ov -format UDZO "$DMG_PATH" 2>&1 | tail -3
    }
else
    echo "  (create-dmg not installed; using hdiutil)"
    hdiutil create -volname "$DMG_VOLNAME" -srcfolder "$APP_DIR" \
        -ov -format UDZO "$DMG_PATH" 2>&1 | tail -3
fi

# ---- 6. Notarise + staple (optional) --------------------------------------
# If NOTARIZE_PROFILE env var is set (matching `xcrun notarytool store-credentials`
# profile name), submit the DMG to Apple's notarisation service, wait for the
# verdict, then staple the ticket onto both the .app and the DMG so Gatekeeper
# accepts them offline.
if [[ -n "${NOTARIZE_PROFILE:-}" ]]; then
    echo "[6/7] Submitting DMG to Apple notarisation service…"
    if xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait 2>&1 | tee /tmp/notarise.log | tail -20; then

        STATUS=$(grep -i "^[[:space:]]*status:" /tmp/notarise.log | tail -1 | awk '{print $2}')
        if [[ "$STATUS" == "Accepted" ]]; then
            echo "  → notarisation accepted. Stapling ticket…"
            xcrun stapler staple "$APP_DIR"  2>&1 | tail -3
            xcrun stapler staple "$DMG_PATH" 2>&1 | tail -3
            echo "  ✅ Stapled. Gatekeeper will accept this app offline."
        else
            echo "  ❌ Notarisation status: $STATUS"
            echo "     Run: xcrun notarytool log <submission-id> --keychain-profile $NOTARIZE_PROFILE"
            echo "     to see Apple's reject reasons."
        fi
    else
        echo "  ❌ Notarisation submission failed. See /tmp/notarise.log"
    fi
fi

# ---- 7. Report ------------------------------------------------------------
echo "[7/7] Done."
APP_SIZE="$(du -sh "$APP_DIR" | awk '{print $1}')"
DMG_SIZE="$(du -sh "$DMG_PATH" | awk '{print $1}')"
echo ""
echo "✅ Build complete."
echo "   App  : $APP_DIR  ($APP_SIZE)"
echo "   DMG  : $DMG_PATH  ($DMG_SIZE)"
echo ""
if [[ -n "${NOTARIZE_PROFILE:-}" ]]; then
    echo "Notarised + stapled — double-click works, no right-click → Open needed."
else
    echo "First launch: right-click → Open (ad-hoc signed)"
    echo ""
    echo "To produce a notarised release build, set:"
    echo "  DEVELOPER_ID_IDENTITY=\"Developer ID Application: Name (TEAMID)\""
    echo "  NOTARIZE_PROFILE=MultiScriptOCR-Notary"
    echo "  bash build.sh"
fi
