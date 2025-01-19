//import SwiftUI
//import Combine
//
//class PDFManager: ObservableObject {
//    @Published var pdfs: [URL] = []
//    private let folderName = "MyPDFs"
//    private let folderURL: URL
//    private var folderMonitor: FolderMonitor?
//
//    init() {
//        folderURL = FileManagerHelper.shared.createAppFolder(named: folderName)
//        loadPDFs()
//        folderMonitor = FolderMonitor(folderURL: folderURL) { [weak self] in
//            self?.loadPDFs()
//        }
//    }
//
//    func loadPDFs() {
//        pdfs = FileManagerHelper.shared.listFiles(in: folderURL).filter { $0.pathExtension == "pdf" }
//    }
//
//    func savePDF(_ url: URL) {
//        let destinationURL = folderURL.appendingPathComponent(url.lastPathComponent)
//        do {
//            try FileManager.default.copyItem(at: url, to: destinationURL)
//            loadPDFs()
//        } catch {
//            print("Error saving PDF: \(error)")
//        }
//    }
//}
//
