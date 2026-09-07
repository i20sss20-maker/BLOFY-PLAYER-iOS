import SwiftUI
import AVFoundation

@main
struct BlofyPlayerApp: App {
    @StateObject private var model = AppModel()

    init() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            // Playback still works without background audio privileges; the player layer handles the error path.
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environmentObject(model)
        }
    }
}
