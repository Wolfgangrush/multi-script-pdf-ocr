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
        public var formatted: String {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useMB, .useKB]
            bcf.countStyle = .file
            return "\(bcf.string(fromByteCount: inputBytes)) → \(bcf.string(fromByteCount: outputBytes))"
        }
    }

    /// Reduce a PDF by rasterizing each page at 150 DPI and JPEG-recompressing
    /// at quality 0.7. Reliable replacement for the v0.1 Quartz-filter approach,
    /// which depended on the undocumented "QuartzFilter" CGContext option that
    /// no longer applies cleanly under sandbox.
    ///
    /// Tradeoffs vs system-level reduce-size workflows:
    /// - Output PDF is image-only (no text layer preserved). Acceptable because
    ///   most legal-doc bundles RSH receives are already scans.
    /// - Predictable size reduction: typically 60-85% on scanned bundles, 30-50%
    ///   on PDFs that were already digital.
    /// - For PDFs with native text we lose searchability. v0.2 can detect
    ///   text-bearing pages and skip rasterization for them.
    public func reduce(pdf: PDFDocument, sourceURL: URL, outputURL: URL) throws -> Result {
        let inputBytes = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0

        let pageCount = pdf.pageCount
        guard pageCount > 0 else {
            throw OCRError.engineFailure("Source PDF has 0 pages")
        }

        // Use first page mediabox for the document context default. CGContext
        // accepts per-page mediaboxes via beginPage anyway — this is a hint.
        guard let firstPage = pdf.page(at: 0) else {
            throw OCRError.engineFailure("Could not read first page")
        }
        var firstBox = firstPage.bounds(for: .mediaBox)

        // Remove any pre-existing file at outputURL (NSSavePanel may not auto-overwrite).
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        guard let ctx = CGContext(outputURL as CFURL, mediaBox: &firstBox, [
            kCGPDFContextCreator as String: "OCR Reader v0.1.1",
            kCGPDFContextTitle as String: outputURL.deletingPathExtension().lastPathComponent
        ] as CFDictionary) else {
            throw OCRError.engineFailure("CGContext creation failed at \(outputURL.path)")
        }

        for i in 0..<pageCount {
            guard let page = pdf.page(at: i) else { continue }
            var box = page.bounds(for: .mediaBox)

            // Render the page at 150 DPI. PDF points are 72 DPI baseline.
            let dpi: CGFloat = 150
            let scale = dpi / 72.0
            let pxW = Int(box.width * scale)
            let pxH = Int(box.height * scale)

            guard let bitmapCtx = CGContext(
                data: nil,
                width: pxW, height: pxH,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { continue }

            bitmapCtx.setFillColor(CGColor.white)
            bitmapCtx.fill(CGRect(x: 0, y: 0, width: pxW, height: pxH))
            bitmapCtx.scaleBy(x: scale, y: scale)
            bitmapCtx.translateBy(x: -box.origin.x, y: -box.origin.y)
            page.draw(with: .mediaBox, to: bitmapCtx)

            guard let cgImage = bitmapCtx.makeImage() else { continue }

            // Re-encode as JPEG at quality 0.7 → wrap as a JPEG-bearing PDF page.
            // We do this by drawing the CGImage into a fresh PDF page context.
            let jpegData = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(jpegData, UTType.jpeg.identifier as CFString, 1, nil)
            else { continue }
            CGImageDestinationAddImage(dest, cgImage, [
                kCGImageDestinationLossyCompressionQuality: 0.7
            ] as CFDictionary)
            guard CGImageDestinationFinalize(dest) else { continue }

            // Decode JPEG back to a CGImage so the PDF context stores it as a
            // JPEG-encoded XObject (vs re-encoding raw bitmap).
            guard let provider = CGDataProvider(data: jpegData as CFData),
                  let jpegImage = CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            else { continue }

            ctx.beginPage(mediaBox: &box)
            ctx.draw(jpegImage, in: box)
            ctx.endPage()
        }

        ctx.closePDF()

        let outputBytes = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        if outputBytes == 0 {
            throw OCRError.engineFailure("Output file is empty (write failed silently)")
        }
        return Result(inputBytes: inputBytes, outputBytes: outputBytes)
    }
}
