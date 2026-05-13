import Foundation
import SwiftUI
import PDFKit
import AppKit
import UniformTypeIdentifiers

enum BannerLevel {
    case success
    case info
    case error
}

struct BannerMessage: Equatable {
    let text: String
    let level: BannerLevel
    let autoDismiss: Bool
    let id = UUID()

    static func == (lhs: BannerMessage, rhs: BannerMessage) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class DocumentModel: ObservableObject {
    @Published var document: PDFDocument?
    @Published var fileURL: URL?
    @Published var isRunningOCR = false
    @Published var ocrProgressText = ""
    @Published var isSavingReduced = false
    @Published var banner: BannerMessage?

    @Published var ocrPages: [String] = []
    @Published var showOCRSidebar = false

    @Published var selectedLanguage: OCRLanguage = .english

    var fileName: String? { fileURL?.lastPathComponent }

    var ocrAllText: String {
        ocrPages.enumerated().map { "── Page \($0.offset + 1) ──\n\($0.element)" }.joined(separator: "\n\n")
    }

    func openWithPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] resp in
            guard resp == .OK, let url = panel.url else { return }
            self?.open(url: url)
        }
    }

    func open(url: URL) {
        guard let pdf = PDFDocument(url: url) else {
            showBanner("Could not open PDF.", level: .error)
            return
        }
        self.document = pdf
        self.fileURL = url
        self.ocrPages = []
        self.showOCRSidebar = false
        dismissBanner()
    }

    func runOCR() async {
        guard let pdf = document else { return }
        isRunningOCR = true
        defer {
            isRunningOCR = false
            ocrProgressText = ""
        }

        let total = pdf.pageCount
        ocrPages = Array(repeating: "", count: total)

        let engine: OCREngine = selectedLanguage.usesVision
            ? VisionOCREngine()
            : TesseractOCREngine(language: selectedLanguage)

        let service = PDFOCRService(engine: engine)
        do {
            try await service.process(
                pdf: pdf,
                progress: { [weak self] page in
                    Task { @MainActor in self?.ocrProgressText = "OCR \(page) / \(total)" }
                },
                pageText: { [weak self] page, text in
                    Task { @MainActor in
                        guard let self else { return }
                        if page - 1 < self.ocrPages.count {
                            self.ocrPages[page - 1] = text
                        }
                    }
                }
            )
            self.showOCRSidebar = true
            showBanner(
                "OCR complete on \(total) page\(total == 1 ? "" : "s") · \(selectedLanguage.displayName)",
                level: .success
            )
        } catch OCRError.cancelled {
            showBanner("OCR cancelled.", level: .info)
        } catch OCRError.toolMissing(let msg) {
            showBanner("Tesseract not bundled correctly: \(msg)", level: .error)
        } catch {
            showBanner("OCR failed: \(error.localizedDescription)", level: .error)
        }
    }

    func saveReduced() {
        guard let pdf = document, let src = fileURL else { return }
        if isSavingReduced { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = src.deletingPathExtension().lastPathComponent + "-reduced.pdf"
        panel.directoryURL = src.deletingLastPathComponent()
        panel.prompt = "Save Reduced PDF"
        panel.message = "Choose where to save the reduced-size PDF."
        panel.begin { [weak self] resp in
            guard resp == .OK, let outURL = panel.url else { return }
            Task { @MainActor [weak self] in
                await self?.performSaveReduced(pdf: pdf, sourceURL: src, outputURL: outURL)
            }
        }
    }

    private func performSaveReduced(pdf: PDFDocument, sourceURL: URL, outputURL: URL) async {
        isSavingReduced = true
        showBanner("Compressing \(sourceURL.lastPathComponent)…", level: .info, autoDismiss: false)
        // Yield so the spinner/banner render before PDFKit blocks the main thread.
        await Task.yield()
        defer { isSavingReduced = false }

        do {
            let result = try PDFReducer.shared.reduce(pdf: pdf, sourceURL: sourceURL, outputURL: outputURL)
            let pages = "\(result.pagesRasterised) rasterised · \(result.pagesPreserved) preserved"
            showBanner(
                "Saved \(outputURL.lastPathComponent) — \(result.ratioPercent)% of original (\(result.formatted)) · \(pages)",
                level: .success
            )
        } catch OCRError.alreadyOptimised(let msg) {
            showBanner(msg, level: .info)
        } catch {
            showBanner("Save failed: \(error.localizedDescription)", level: .error)
        }
    }

    func copyOCRText() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(ocrAllText, forType: .string)
        showBanner("OCR text copied to clipboard.", level: .success)
    }

    // MARK: - Banner

    private func showBanner(_ text: String, level: BannerLevel, autoDismiss: Bool? = nil) {
        let auto = autoDismiss ?? (level == .success)
        let message = BannerMessage(text: text, level: level, autoDismiss: auto)
        banner = message
        if auto {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    guard let self else { return }
                    if self.banner?.id == message.id { self.banner = nil }
                }
            }
        }
    }

    func dismissBanner() {
        banner = nil
    }
}
