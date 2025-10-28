import UIKit
import Social
import SwiftUI
import SwiftData

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // --- MODIFICATION 1: Get ALL attachments ---
        // We now loop through all input items and all attachments
        // and collect them into an array.
        let attachments: [NSItemProvider] = {
            guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else { return [] }
            // Use flatMap to collect all attachments from all items
            return inputItems.flatMap { $0.attachments ?? [] }
        }()
        
        // --- MODIFICATION 2: Check if the array is empty ---
        guard !attachments.isEmpty else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        // --- MODIFICATION 3: Pass the whole array to ShareView ---
        // The argument is now 'attachments' (plural)
        let shareView = ShareView(attachments: attachments) {
            // This is the completion handler. When the user taps "Save" in our SwiftUI view,
            // this code will run to close the extension.
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }

        // Embed the SwiftUI view within a UIHostingController.
        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.frame = self.view.bounds
        self.view.addSubview(hostingController.view)
        self.addChild(hostingController)
        hostingController.didMove(toParent: self)
    }
}
