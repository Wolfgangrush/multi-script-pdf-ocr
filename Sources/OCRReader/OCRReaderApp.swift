import SwiftUI

@main
struct LegalOCRReaderApp: App {
    @StateObject private var doc = DocumentModel()

    var body: some Scene {
        WindowGroup("Legal OCR Reader") {
            ContentView()
                .environmentObject(doc)
                .frame(minWidth: 700, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDF…") { doc.openWithPanel() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Reduced") { doc.saveReduced() }
                    .keyboardShortcut("s")
                    .disabled(doc.document == nil)
            }
        }
    }
}
