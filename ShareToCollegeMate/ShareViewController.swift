import UIKit
import Social
import SwiftUI
import SwiftData

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        // Create the SwiftUI view that will be the UI of the extension.
        let shareView = ShareView(attachment: attachment) {
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
