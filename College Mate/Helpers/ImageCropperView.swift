import SwiftUI
import Mantis

/// A view that wraps the Mantis image cropping library.
struct ImageCropperView: UIViewControllerRepresentable {
    
    /// The image that needs to be cropped.
    let image: UIImage
    
    /// A callback that returns the newly cropped image.
    let onCrop: (UIImage) -> Void
    
    /// A binding to control the presentation of this view.
    @Binding var isPresented: Bool
    
    /// Creates the Mantis CropViewController.
    func makeUIViewController(context: Context) -> UIViewController {
        // Create a new configuration for the cropper.
        var config = Mantis.Config()
        config.cropToolbarConfig.toolbarButtonOptions = [.clockwiseRotate, .reset, .ratio]
        
        // Create the CropViewController with the image and configuration.
        let cropViewController = Mantis.cropViewController(image: image, config: config)
        cropViewController.delegate = context.coordinator
        return cropViewController
    }
    
    /// This is required by the protocol but not needed for this implementation.
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    /// Creates the coordinator that will handle delegate callbacks from the cropper.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    /// The Coordinator acts as a bridge between the UIKit-based CropViewController and our SwiftUI view.
    class Coordinator: NSObject, CropViewControllerDelegate {
        var parent: ImageCropperView
        
        init(_ parent: ImageCropperView) {
            self.parent = parent
        }
        
        // --- Corrected Delegate Methods ---
        
        func cropViewControllerDidCrop(_ cropViewController: Mantis.CropViewController, cropped: UIImage, transformation: Mantis.Transformation, cropInfo: Mantis.CropInfo) {
            parent.onCrop(cropped)
            parent.isPresented = false
        }
        
        // This version of the cancel method is now implemented.
        func cropViewControllerDidCancel(_ cropViewController: Mantis.CropViewController, original: UIImage) {
            parent.isPresented = false
        }
        
        // The other optional methods are left empty as they are not needed for our implementation.
        func cropViewControllerDidFailToCrop(_ cropViewController: Mantis.CropViewController, original: UIImage) {}
        func cropViewControllerDidBeginResize(_ cropViewController: Mantis.CropViewController) {}
        func cropViewControllerDidEndResize(_ cropViewController: Mantis.CropViewController, original: UIImage, cropInfo: Mantis.CropInfo) {}
    }
}
