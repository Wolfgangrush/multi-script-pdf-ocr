import Foundation
import PDFKit
import AppKit
import CoreGraphics

/// Orchestrates: render PDF page → engine → return recognized text.
///
/// v0.1.1 change: this service NO LONGER mutates the PDFDocument. Embedding
/// invisible text via PDFAnnotation freeText looked clean on paper but PDFKit
/// renders those annotations with an opaque background regardless of clear
/// color settings — produced black rectangles in v0.1 user testing. Side-panel
/// OCR text is the clean replacement.
public actor PDFOCRService {
    private let engine: OCREngine

    public init(engine: OCREngine) {
        self.engine = engine
    }

    /// Process every page.
    /// - `progress`: 1-based page number on completion of each page.
    /// - `pageText`: 1-based page number + concatenated recognized text for that page.
    public func process(
        pdf: PDFDocument,
        progress: @Sendable @escaping (Int) -> Void,
        pageText: @Sendable @escaping (Int, String) -> Void
    ) async throws {
        let total = pdf.pageCount
        for i in 0..<total {
            try Task.checkCancellation()
            guard let page = pdf.page(at: i) else { continue }
            let boxes = try await ocrPage(page: page)
            // Sort boxes top-to-bottom, then left-to-right for natural reading order.
            let ordered = boxes.sorted { (a, b) in
                if abs(a.rect.origin.y - b.rect.origin.y) > 0.01 {
                    return a.rect.origin.y > b.rect.origin.y // y is bottom-origin → higher = top
                }
                return a.rect.origin.x < b.rect.origin.x
            }
            let text = ordered.map { $0.text }.joined(separator: "\n")
            pageText(i + 1, text)
            progress(i + 1)
        }
    }

    private func ocrPage(page: PDFPage) async throws -> [RecognizedText] {
        let cg = try await Self.renderPage(page)
        return try await engine.recognize(cgImage: cg)
    }

    /// Render a PDFPage to a CGImage at 2× scale via a CGContext.
    /// CGImage is Sendable on macOS 13+; NSImage is not, so we avoid it here.
    /// Honours page rotation — rotated scans (90/270°) are rendered upright
    /// so the OCR engine sees them in reading orientation.
    @MainActor
    private static func renderPage(_ page: PDFPage) throws -> CGImage {
        let box = page.bounds(for: .mediaBox)
        let rotation = page.rotation
        let display: CGSize = (rotation == 90 || rotation == 270)
            ? CGSize(width: box.height, height: box.width)
            : CGSize(width: box.width, height: box.height)

        let scale: CGFloat = 2.0
        let pxW = max(Int(display.width * scale), 1)
        let pxH = max(Int(display.height * scale), 1)

        guard let ctx = CGContext(
            data: nil,
            width: pxW, height: pxH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw OCRError.engineFailure("Failed to allocate render context")
        }
        ctx.setFillColor(CGColor.white)
        ctx.fill(CGRect(x: 0, y: 0, width: pxW, height: pxH))
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)

        guard let img = ctx.makeImage() else {
            throw OCRError.engineFailure("Failed to capture page bitmap")
        }
        return img
    }
}
