import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Spawns the bundled Tesseract binary as a subprocess.
///
/// Layout inside the .app:
///   Contents/MacOS/tesseract           (the binary, copied from Homebrew)
///   Contents/Frameworks/*.dylib        (transitive dylib deps, paths fixed by dylibbundler)
///   Contents/Resources/tessdata/*.traineddata  (language data)
///
/// Sandbox is disabled because subprocess execution is incompatible with sandbox.
/// The app makes no network calls; offline-only is preserved.
public struct TesseractOCREngine: OCREngine {
    public let language: OCRLanguage

    public init(language: OCRLanguage) {
        self.language = language
    }

    public func recognize(cgImage: CGImage) async throws -> [RecognizedText] {
        guard let langCode = language.tesseractCode else {
            throw OCRError.engineFailure("Tesseract called for non-Tesseract language")
        }
        let bundle = Bundle.main
        guard let resourcePath = bundle.resourcePath else {
            throw OCRError.engineFailure("Bundle resourcePath unavailable")
        }
        let bundlePath = bundle.bundlePath  // .../Multi-Script PDF OCR.app
        let tesseractURL = URL(fileURLWithPath: bundlePath)
            .appendingPathComponent("Contents/MacOS/tesseract")
        let tessdataDir = URL(fileURLWithPath: resourcePath)
            .appendingPathComponent("tessdata")

        guard FileManager.default.isExecutableFile(atPath: tesseractURL.path) else {
            throw OCRError.toolMissing("Bundled Tesseract not found at \(tesseractURL.path)")
        }

        // Encode page to a temp PNG.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ocr-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard let dest = CGImageDestinationCreateWithURL(tmp as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            throw OCRError.engineFailure("PNG encoder unavailable")
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw OCRError.engineFailure("PNG encoding failed")
        }

        // Run tesseract on a background queue.
        let text = try await Task.detached(priority: .userInitiated) {
            try Self.runTesseract(
                binary: tesseractURL,
                inputImage: tmp,
                tessdataDir: tessdataDir,
                language: langCode
            )
        }.value

        return [RecognizedText(rect: CGRect(x: 0, y: 0, width: 1, height: 1), text: text)]
    }

    /// Runs `tesseract input.png stdout -l <lang> --tessdata-dir <path>` and returns stdout.
    private static func runTesseract(
        binary: URL,
        inputImage: URL,
        tessdataDir: URL,
        language: String
    ) throws -> String {
        let proc = Process()
        proc.executableURL = binary
        proc.arguments = [
            inputImage.path,
            "stdout",
            "-l", language,
            "--tessdata-dir", tessdataDir.path,
            "--psm", "3"  // fully automatic page segmentation, no OSD
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr

        do {
            try proc.run()
        } catch {
            throw OCRError.engineFailure("Failed to launch Tesseract: \(error.localizedDescription)")
        }
        proc.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        if proc.terminationStatus != 0 {
            let errStr = String(data: errData, encoding: .utf8) ?? "?"
            throw OCRError.engineFailure("Tesseract exit \(proc.terminationStatus): \(errStr.prefix(300))")
        }

        return String(data: outData, encoding: .utf8) ?? ""
    }
}
