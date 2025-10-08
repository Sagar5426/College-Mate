import UIKit
import SwiftUI

final class ShareExtensionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let provider: NSItemProvider? = {
            guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
            for item in inputItems {
                if let attachments = item.attachments {
                    for attachment in attachments {
                        return attachment
                    }
                }
            }
            return nil
        }()
        
        guard let itemProvider = provider else {
            let errorLabel = UILabel()
            errorLabel.text = "No valid attachment found."
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
        
        let shareView = ShareView(attachment: itemProvider, onComplete: { [weak self] in
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
