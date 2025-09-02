import SwiftUI


enum NoteFilter: String, CaseIterable {
    case all = "All"
    case images = "Images"
    case pdfs = "PDFs"
    case docs = "Docs"
}

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct PreviewableDocument: Identifiable {
    let id = UUID()
    let url: URL
}
