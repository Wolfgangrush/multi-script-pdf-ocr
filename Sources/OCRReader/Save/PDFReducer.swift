import Foundation
import PDFKit
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public final class PDFReducer {
    public static let shared = PDFReducer()
    private init() {}

    public struct Result {
        public let inputBytes: Int64
        public let outputBytes: Int64
        public let pagesRasterised: Int
        public let pagesPreserved: Int

        public var ratioPercent: Int {
            guard inputBytes > 0 else { return 0 }
            return Int(round(Double(outputBytes) / Double(inputBytes) * 100))
        }

        public var formatted: String {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useMB, .useKB]
            bcf.countStyle = .file
            return "\(bcf.string(fromByteCount: inputBytes)) → \(bcf.string(fromByteCount: outputBytes))"
        }
    }

    // Selective compressor.
    //
    // v0.2 behaviour (replaced): rasterised every page at 150 DPI / JPEG 0.7,
    // which inflated digital-text PDFs and many low-DPI scans.
    //
    // v0.3 behaviour:
    //   • Pages with a real text layer are copied through unchanged
    //     (preserves searchability and stays tiny).
    //   • Image-only / scan pages are rasterised at 110 DPI, JPEG 0.55,
    //     honouring page rotation so output displays upright.
    //   • If the resulting PDF would be ≥ the input size (i.e. the source
    //     is already optimised), we refuse to write and throw — the caller
    //     surfaces this as a banner instead of silently producing a
    //     larger "reduced" copy.
    public func reduce(pdf: PDFDocument, sourceURL: URL, outputURL: URL) throws -> Result {
        let inputBytes = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0

        let pageCount = pdf.pageCount
        guard pageCount > 0 else {
            throw OCRError.engineFailure("Source PDF has 0 pages")
        }

        let outDoc = PDFDocument()
        var rasterised = 0
        var preserved = 0

        for i in 0..<pageCount {
            guard let page = pdf.page(at: i) else { continue }

            if pageHasMeaningfulText(page) {
                if let copy = page.copy() as? PDFPage {
                    outDoc.insert(copy, at: outDoc.pageCount)
                    preserved += 1
                    continue
                }
            }

            if let rasterPage = rasterisedPage(from: page) {
                outDoc.insert(rasterPage, at: outDoc.pageCount)
                rasterised += 1
            } else if let copy = page.copy() as? PDFPage {
                outDoc.insert(copy, at: outDoc.pageCount)
                preserved += 1
            }
        }

        guard let outData = outDoc.dataRepresentation() else {
            throw OCRError.engineFailure("Could not serialise output PDF")
        }

        let outputBytes = Int64(outData.count)

        if inputBytes > 0 && outputBytes >= inputBytes {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useMB, .useKB]
            bcf.countStyle = .file
            throw OCRError.alreadyOptimised(
                "PDF already well-compressed — no reduction possible. " +
                "Source is \(bcf.string(fromByteCount: inputBytes)); a re-encoded copy would be " +
                "\(bcf.string(fromByteCount: outputBytes)). No file written."
            )
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        try outData.write(to: outputURL)

        return Result(
            inputBytes: inputBytes,
            outputBytes: outputBytes,
            pagesRasterised: rasterised,
            pagesPreserved: preserved
        )
    }

    // 80 non-whitespace chars is the threshold for "real text layer" — filters
    // out stray page numbers / scan artefacts that show up as 1-3 chars on
    // some image-only PDFs.
    private func pageHasMeaningfulText(_ page: PDFPage) -> Bool {
        guard let raw = page.string else { return false }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 80
    }

    private func rasterisedPage(from page: PDFPage) -> PDFPage? {
        let mediaBox = page.bounds(for: .mediaBox)
        let rotation = page.rotation

        let displaySize: CGSize = (rotation == 90 || rotation == 270)
            ? CGSize(width: mediaBox.height, height: mediaBox.width)
            : CGSize(width: mediaBox.width, height: mediaBox.height)

        let dpi: CGFloat = 110
        let scale = dpi / 72.0
        let pxW = max(1, Int(displaySize.width * scale))
        let pxH = max(1, Int(displaySize.height * scale))

        guard let bitmapCtx = CGContext(
            data: nil,
            width: pxW, height: pxH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        bitmapCtx.setFillColor(CGColor.white)
        bitmapCtx.fill(CGRect(x: 0, y: 0, width: pxW, height: pxH))
        bitmapCtx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: bitmapCtx)

        guard let cgImage = bitmapCtx.makeImage() else { return nil }

        let jpegData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            jpegData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, cgImage, [
            kCGImageDestinationLossyCompressionQuality: 0.55
        ] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }

        guard let nsImage = NSImage(data: jpegData as Data) else { return nil }
        nsImage.size = displaySize
        return PDFPage(image: nsImage)
    }
}
