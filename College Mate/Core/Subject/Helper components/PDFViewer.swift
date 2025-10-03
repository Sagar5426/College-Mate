import SwiftUI
import PDFKit

struct PDFViewer: View {
    let url: URL

    var body: some View {
        PDFKitView(url: url)
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
