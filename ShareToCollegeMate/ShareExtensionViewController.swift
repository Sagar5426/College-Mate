import UIKit
import SwiftUI

final class ShareExtensionViewController: UIViewController {

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
            let errorLabel = UILabel()
            errorLabel.text = "No valid attachments found."
            errorLabel.textAlignment = .center
            errorLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let closeButton = UIButton(type: .system)
            closeButton.setTitle("Close", for: .normal)
            closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            
            view.addSubview(errorLabel)
            view.addSubview(closeButton)
            
            NSLayoutConstraint.activate([
                errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                
                closeButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
                closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
            
            return
        }
        
        // --- MODIFICATION 3: Pass the whole array to ShareView ---
        let shareView = ShareView(attachments: attachments, onComplete: { [weak self] in
            self?.completeExtension()
        })
        
        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    @objc private func closeButtonTapped() {
        cancelExtension()
    }
    
    private func completeExtension() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
    
    private func cancelExtension() {
        let error = NSError(domain: "ShareExtension", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cancelled"])
        self.extensionContext?.cancelRequest(withError: error)
    }
}
