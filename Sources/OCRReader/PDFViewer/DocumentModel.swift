import Foundation
import SwiftUI
import PDFKit
import AppKit
import UniformTypeIdentifiers

@MainActor
final class DocumentModel: ObservableObject {
    @Published var document: PDFDocument?
    @Published var fileURL: URL?
    @Published var isRunningOCR = false
    @Published var ocrProgressText = ""
    @Published var banner: String?

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
            showBanner("Could not open PDF.")
            return
        }
        self.document = pdf
        self.fileURL = url
        self.ocrPages = []
        self.showOCRSidebar = false
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
            showBanner("OCR complete on \(total) page\(total == 1 ? "" : "s") · \(selectedLanguage.displayName)")
        } catch OCRError.cancelled {
            showBanner("OCR cancelled.")
        } catch OCRError.toolMissing(let msg) {
            showBanner("Tesseract not bundled correctly: \(msg)")
        } catch {
            showBanner("OCR failed: \(error.localizedDescription)")
        }
    }

    func saveReduced() {
        guard let pdf = document, let src = fileURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = src.deletingPathExtension().lastPathComponent + "-reduced.pdf"
        panel.directoryURL = src.deletingLastPathComponent()
        panel.prompt = "Save Reduced PDF"
        panel.message = "Choose where to save the reduced-size PDF."
        panel.begin { [weak self] resp in
            guard resp == .OK, let outURL = panel.url else { return }
            Task { @MainActor in
                self?.performSaveReduced(pdf: pdf, sourceURL: src, outputURL: outURL)
            }
        }
    }

    private func performSaveReduced(pdf: PDFDocument, sourceURL: URL, outputURL: URL) {
        do {
            let result = try PDFReducer.shared.reduce(pdf: pdf, sourceURL: sourceURL, outputURL: outputURL)
            let ratio = Int(round(Double(result.outputBytes) / Double(result.inputBytes) * 100))
            showBanner("Saved \(outputURL.lastPathComponent) — \(ratio)% of original (\(result.formatted))")
        } catch {
            showBanner("Save failed: \(error.localizedDescription)")
        }
    }

    func copyOCRText() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(ocrAllText, forType: .string)
        showBanner("OCR text copied to clipboard.")
    }

    private func showBanner(_ text: String) {
        banner = text
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if self.banner == text { self.banner = nil }
            }
        }
    }
}
