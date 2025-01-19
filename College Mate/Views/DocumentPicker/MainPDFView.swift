////
////  MainPDFView.swift
////  College Mate
////
////  Created by Sagar Jangra on 16/01/2025.
////
//
//import SwiftUI
//import MobileCoreServices
//import PDFKit
//
//struct MainPDFView: View {
//    @StateObject private var pdfManager = PDFManager()
//    @State private var showDocumentPicker = false
//
//    private let columns = [
//        GridItem(.flexible()),
//        GridItem(.flexible()),
//        GridItem(.flexible())
//    ]
//
//    var body: some View {
//        NavigationView {
//            VStack {
//                if pdfManager.pdfs.isEmpty {
//                    Text("No PDFs Available")
//                        .foregroundColor(.gray)
//                        .padding()
//                } else {
//                    ScrollView {
//                        LazyVGrid(columns: columns, spacing: 16) {
//                            ForEach(pdfManager.pdfs, id: \.self) { pdf in
//                                NavigationLink(destination: PDFViewer(pdfURL: pdf)) {
//                                    VStack {
//                                        PDFThumbnailView(pdfURL: pdf)
//                                            .frame(width: 100, height: 140)
//                                            .cornerRadius(8)
//                                            .shadow(radius: 3)
//
//                                        Text(pdf.lastPathComponent)
//                                            .lineLimit(1)
//                                            .font(.caption)
//                                            .frame(maxWidth: 100)
//                                            .truncationMode(.middle)
//                                    }
//                                }
//                            }
//                        }
//                        .padding()
//                    }
//                }
//
//                Button("Import PDF") {
//                    showDocumentPicker.toggle()
//                }
//                .sheet(isPresented: $showDocumentPicker) {
//                    DocumentPicker(allowedContentTypes: [.pdf]) { url in
//                        pdfManager.savePDF(url)
//                    }
//                }
//            }
//            .navigationTitle("My PDFs")
//            .onAppear {
//                pdfManager.loadPDFs()
//            }
//        }
//    }
//}
//
//// Document Picker for Importing PDFs
//import UniformTypeIdentifiers
//
//struct DocumentPicker: UIViewControllerRepresentable {
//    var allowedContentTypes: [UTType]
//    var onPick: (URL) -> Void
//
//    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
//        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
//        picker.delegate = context.coordinator
//        return picker
//    }
//
//    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
//
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(onPick: onPick)
//    }
//
//    class Coordinator: NSObject, UIDocumentPickerDelegate {
//        var onPick: (URL) -> Void
//
//        init(onPick: @escaping (URL) -> Void) {
//            self.onPick = onPick
//        }
//
//        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
//            if let url = urls.first {
//                onPick(url)
//            }
//        }
//    }
//}
//
//// PDF Manager to Handle File Operations
//import Combine
//
//class PDFManager: ObservableObject {
//    @Published var pdfs: [URL] = []
//
//    private var folderURL: URL {
//        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        return documentsURL.appendingPathComponent("PDFs")
//    }
//
//    init() {
//        loadPDFs()
//    }
//
//    func loadPDFs() {
//        do {
//            let urls = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
//            pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
//        } catch {
//            print("Error loading PDFs: \(error.localizedDescription)")
//        }
//    }
//
//    func savePDF(_ url: URL) {
//        do {
//            let fileManager = FileManager.default
//            if !fileManager.fileExists(atPath: folderURL.path) {
//                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
//            }
//
//            let destinationURL = folderURL.appendingPathComponent(url.lastPathComponent)
//            if fileManager.fileExists(atPath: destinationURL.path) {
//                print("File already exists at \(destinationURL.path)")
//            } else {
//                try fileManager.copyItem(at: url, to: destinationURL)
//                loadPDFs()
//            }
//        } catch {
//            print("Error saving PDF: \(error.localizedDescription)")
//        }
//    }
//}
//
//// PDF Viewer and Thumbnail Generation
//struct PDFThumbnailView: View {
//    let pdfURL: URL
//
//    var body: some View {
//        if let image = generatePDFThumbnail(for: pdfURL) {
//            Image(uiImage: image)
//                .resizable()
//                .scaledToFit()
//        } else {
//            Color.gray
//                .overlay(Text("No Preview").foregroundColor(.white))
//        }
//    }
//
//    private func generatePDFThumbnail(for url: URL) -> UIImage? {
//        guard let pdfDocument = PDFDocument(url: url), let page = pdfDocument.page(at: 0) else {
//            return nil
//        }
//
//        let pageRect = page.bounds(for: .mediaBox)
//        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
//        let image = renderer.image { ctx in
//            UIColor.white.set()
//            ctx.fill(pageRect)
//            page.draw(with: .mediaBox, to: ctx.cgContext)
//        }
//        return image
//    }
//}
//
//struct PDFViewer: View {
//    let pdfURL: URL
//
//    var body: some View {
//        PDFKitView(pdfURL: pdfURL)
//            .edgesIgnoringSafeArea(.all)
//            .navigationTitle(pdfURL.lastPathComponent)
//            .navigationBarTitleDisplayMode(.inline)
//    }
//}
//
//struct PDFKitView: UIViewRepresentable {
//    var pdfURL: URL
//
//    func makeUIView(context: Context) -> PDFView {
//        let pdfView = PDFView()
//        pdfView.document = PDFDocument(url: pdfURL)
//        pdfView.autoScales = true
//        return pdfView
//    }
//
//    func updateUIView(_ uiView: PDFView, context: Context) {}
//}
//
//extension URL: @retroactive Identifiable {
//    public var id: String {
//        self.absoluteString
//    }
//}
