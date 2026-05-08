import SwiftUI

struct ContentView: View {
    @EnvironmentObject var doc: DocumentModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                ZStack {
                    if doc.document == nil {
                        emptyState
                    } else {
                        PDFViewerView()
                            .environmentObject(doc)
                    }
                    if let banner = doc.banner {
                        VStack {
                            Spacer()
                            Text(banner)
                                .padding(8)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .padding()
                        }
                    }
                }

                if doc.showOCRSidebar && !doc.ocrPages.isEmpty {
                    Divider()
                    ocrSidebar
                        .frame(width: 360)
                        .background(Color(NSColor.textBackgroundColor))
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: doc.openWithPanel) {
                Label("Open", systemImage: "doc")
            }

            Spacer().frame(width: 8)

            // Language picker — drives which OCR engine runs.
            Picker("Language", selection: $doc.selectedLanguage) {
                ForEach(OCRLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 240)
            .help("OCR language. English uses Apple Vision (on-device, fast). Indian languages use bundled Tesseract — fully offline.")

            Button(action: { Task { await doc.runOCR() } }) {
                if doc.isRunningOCR {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                        Text(doc.ocrProgressText)
                    }
                } else {
                    Label("OCR", systemImage: "text.viewfinder")
                }
            }
            .disabled(doc.document == nil || doc.isRunningOCR)

            Button(action: doc.saveReduced) {
                Label("Save Reduced", systemImage: "arrow.down.circle")
            }
            .disabled(doc.document == nil)
            .keyboardShortcut("s")

            if !doc.ocrPages.isEmpty {
                Button(action: { doc.showOCRSidebar.toggle() }) {
                    Label(doc.showOCRSidebar ? "Hide Text" : "Show Text",
                          systemImage: "text.magnifyingglass")
                }
            }

            Spacer()

            if let name = doc.fileName {
                Text(name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 260)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var ocrSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("OCR Text").font(.headline)
                Spacer()
                Button("Copy All") { doc.copyOCRText() }
                    .controlSize(.small)
                Button(action: { doc.showOCRSidebar = false }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(doc.ocrPages.enumerated()), id: \.offset) { idx, txt in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Page \(idx + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(txt, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .help("Copy this page's text")
                            }
                            Text(txt.isEmpty ? "(no text)" : txt)
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                    }
                }
                .padding(12)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("Open a PDF to begin")
                .foregroundColor(.secondary)
            Button("Open…") { doc.openWithPanel() }
                .controlSize(.large)
        }
    }
}
