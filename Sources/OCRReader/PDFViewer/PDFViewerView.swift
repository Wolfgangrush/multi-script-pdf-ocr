import SwiftUI
import PDFKit

struct PDFViewerView: NSViewRepresentable {
    @EnvironmentObject var doc: DocumentModel

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor.windowBackgroundColor
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== doc.document {
            view.document = doc.document
        }
    }
}
