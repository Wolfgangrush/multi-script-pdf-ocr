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
                            BannerView(message: banner) { doc.dismissBanner() }
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
                if doc.isSavingReduced {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                        Text("Compressing…")
                    }
                } else {
                    Label("Save Reduced", systemImage: "arrow.down.circle")
                }
            }
            .disabled(doc.document == nil || doc.isSavingReduced)
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
                Button(action: doc.closeDocument) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Close this PDF (⌘W)")
                .keyboardShortcut("w")
                .disabled(doc.isRunningOCR || doc.isSavingReduced)
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

private struct BannerView: View {
    let message: BannerMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.system(size: 16, weight: .semibold))
            Text(message.text)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .frame(maxWidth: 520, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if !message.autoDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Dismiss")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(iconColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private var iconName: String {
        switch message.level {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch message.level {
        case .success: return .green
        case .info: return .blue
        case .error: return .orange
        }
    }
}
