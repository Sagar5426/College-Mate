import Foundation
import AVFoundation

/// A robust manager to handle playing custom sound files reliably.
// We make it an NSObject to conform to AVAudioPlayerDelegate.
class SoundService: NSObject, AVAudioPlayerDelegate {
    
    /// A shared singleton instance for easy access.
    static let shared = SoundService()
    
    /// The audio player instance. It's retained here until playback finishes.
    private var audioPlayer: AVAudioPlayer?
    
    // The override is needed because we now inherit from NSObject.
    private override init() {
        super.init()
    }
    
    /// Plays a custom "delete" sound bundled with the app.
    func playDeleteSound() {
        // Ensure you have a sound file named "trash.mp3" in your project's target.
        guard let url = Bundle.main.url(forResource: "trash", withExtension: "mp3") else {
            print("Error: Sound file 'trash.mp3' not found in the app bundle.")
            return
        }

        do {
            // Configure the audio session. This helps prevent conflicts with other audio.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            // Initialize the audio player with the contents of the sound file.
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            
            // Set this class as the delegate to know when the sound finishes.
            audioPlayer?.delegate = self
            
            // Play the sound.
            audioPlayer?.play()
            
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
    
    /// This delegate method is called automatically when the sound has finished playing.
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Now that the sound is done, we can release the player.
        audioPlayer = nil
        
        // Optionally, deactivate the audio session if your app doesn't play other sounds.
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
    }
}
