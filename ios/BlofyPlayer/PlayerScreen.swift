import SwiftUI
import AVKit
import AVFoundation

struct PlayerScreen: View {
    @EnvironmentObject var model: AppModel
    let session: PlaybackSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var box = PlayerBox()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VideoPlayer(player: box.player).ignoresSafeArea()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
            }.padding()
        }
        .onAppear { box.start(url: session.url, seconds: session.start) }
        .onDisappear {
            model.updateResume(item: session.item, seconds: box.current, duration: box.duration)
            box.stop()
        }
    }
}

@MainActor
final class PlayerBox: ObservableObject {
    let player = AVPlayer()
    private var token: Any?
    var current: Double = 0
    var duration: Double = 0

    func start(url: URL, seconds: Double) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        if seconds > 0 { player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) }
        token = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 2, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            let now = time.seconds
            if now.isFinite { self.current = now }
            let total = self.player.currentItem?.duration.seconds ?? 0
            if total.isFinite { self.duration = total }
        }
        player.play()
    }

    func stop() {
        if let token { player.removeTimeObserver(token) }
        token = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}
