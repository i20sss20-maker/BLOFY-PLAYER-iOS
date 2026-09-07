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
            if !box.statusText.isEmpty {
                VStack {
                    Spacer()
                    Text(box.statusText)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.7), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.bottom, 34)
                }
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
            }.padding()
        }
        .onAppear { box.start(session: session) }
        .onDisappear {
            model.updateResume(item: session.item, seconds: box.current, duration: box.duration)
            box.stop()
        }
    }
}

@MainActor
final class PlayerBox: ObservableObject {
    let player = AVPlayer()
    @Published var statusText = ""

    private var token: Any?
    private var watchdog: Timer?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var candidates: [URL] = []
    private var candidateIndex = 0
    private var retriesOnCurrent = 0
    private var isLive = false
    private var requestedStart: Double = 0
    private var openedAt = Date()
    private var lastAdvanceAt = Date()
    private var lastPosition: Double = -1
    private var switching = false

    var current: Double = 0
    var duration: Double = 0

    func start(session: PlaybackSession) {
        stop()
        candidates = session.candidates
        candidateIndex = 0
        retriesOnCurrent = 0
        isLive = session.item.kind == .live
        requestedStart = isLive ? 0 : session.start
        current = requestedStart
        duration = 0
        installTimeObserver()
        playCandidate(at: 0, keepPosition: false)
        watchdog = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkHealth() }
        }
    }

    private func installTimeObserver() {
        token = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            let now = time.seconds
            if now.isFinite {
                self.current = now
                if self.lastPosition < 0 || now - self.lastPosition >= 0.75 {
                    self.lastPosition = now
                    self.lastAdvanceAt = Date()
                    self.statusText = ""
                    self.retriesOnCurrent = 0
                }
            }
            let total = self.player.currentItem?.duration.seconds ?? 0
            if total.isFinite && total > 0 { self.duration = total }
        }
    }

    private func makeItem(url: URL) -> AVPlayerItem {
        let headers = [
            "User-Agent": "BLOFY PLAYER/2.0",
            "Accept": "*/*",
            "Connection": "keep-alive"
        ]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        return AVPlayerItem(asset: asset)
    }

    private func playCandidate(at index: Int, keepPosition: Bool) {
        guard candidates.indices.contains(index), !switching else {
            if !candidates.indices.contains(index) { statusText = "تعذر تشغيل هذا المحتوى" }
            return
        }
        switching = true
        candidateIndex = index
        let resume = isLive ? 0 : (keepPosition ? current : requestedStart)
        let url = candidates[index]
        openedAt = Date()
        lastAdvanceAt = Date()
        lastPosition = -1
        statusText = index == 0 ? "جاري التشغيل…" : "تجربة مسار بديل…"

        statusObservation?.invalidate()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }

        let item = makeItem(url: url)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.status == .failed { self.handleFailure() }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleFailure() }
        }

        player.pause()
        player.replaceCurrentItem(with: item)
        if resume > 0 {
            player.seek(to: CMTime(seconds: resume, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.play()
        switching = false
    }

    private func handleFailure() {
        guard !switching else { return }
        if retriesOnCurrent < 1 {
            retriesOnCurrent += 1
            statusText = "إعادة محاولة…"
            playCandidate(at: candidateIndex, keepPosition: true)
        } else if candidateIndex + 1 < candidates.count {
            retriesOnCurrent = 0
            playCandidate(at: candidateIndex + 1, keepPosition: true)
        } else {
            statusText = "تعذر تشغيل هذا المحتوى"
        }
    }

    private func checkHealth() {
        guard player.currentItem != nil, !switching else { return }
        let now = Date()
        let startupWaiting = lastPosition < 0 && now.timeIntervalSince(openedAt) >= 12
        let stalled = player.timeControlStatus == .waitingToPlayAtSpecifiedRate && now.timeIntervalSince(lastAdvanceAt) >= 12
        let silentLiveStall = isLive && player.timeControlStatus == .playing && now.timeIntervalSince(lastAdvanceAt) >= 12
        if startupWaiting || stalled || silentLiveStall { handleFailure() }
    }

    func stop() {
        watchdog?.invalidate(); watchdog = nil
        statusObservation?.invalidate(); statusObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        if let token { player.removeTimeObserver(token) }
        token = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        candidates = []
        switching = false
    }
}
