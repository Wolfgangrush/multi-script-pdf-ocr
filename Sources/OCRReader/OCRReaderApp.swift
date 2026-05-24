import SwiftUI
import AppKit

@main
struct MultiScriptOCRApp: App {
    @StateObject private var doc = DocumentModel()

    var body: some Scene {
        WindowGroup("Multi-Script PDF OCR") {
            ContentView()
                .environmentObject(doc)
                .frame(minWidth: 700, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDF…") { doc.openWithPanel() }
                    .keyboardShortcut("o")
                Button("Close PDF") { doc.closeDocument() }
                    .keyboardShortcut("w")
                    .disabled(doc.document == nil)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save with OCR…") { doc.saveWithOCR() }
                    .keyboardShortcut("s")
                    .disabled(doc.document == nil || doc.ocrPages.isEmpty)
                Button("Save Reduced…") { doc.saveReduced() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(doc.document == nil)
            }
            CommandGroup(replacing: .help) {
                Button("Contact Support…") {
                    if let url = URL(string: "mailto:wolfgangrush@gmail.com?subject=Multi-Script%20PDF%20OCR%20Support") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
