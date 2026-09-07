import SwiftUI
import AVKit
import AVFoundation
import VLCKit

struct PlayerScreen: View {
    @EnvironmentObject var model: AppModel
    let session: PlaybackSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var box = PlayerBox()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if box.engine == .vlc { VLCVideoSurface(player: box.vlcPlayer).ignoresSafeArea() }
            else { VideoPlayer(player: box.player).ignoresSafeArea() }

            VStack {
                HStack {
                    BlofyBrandMark(compact: true)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(box.engine == .vlc ? BlofyTheme.mint : BlofyTheme.purpleBright).frame(width: 7, height: 7)
                        Text(box.engine == .vlc ? "VLC" : "APPLE").font(.caption2.bold())
                    }
                    .foregroundStyle(BlofyTheme.purpleSoft)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(BlofyTheme.surface.opacity(0.88), in: Capsule())
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).frame(width: 38, height: 38)
                            .background(.black.opacity(0.62), in: Circle()).foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8)
                Spacer()
                if !box.statusText.isEmpty {
                    HStack(spacing: 9) {
                        ProgressView().tint(BlofyTheme.purpleBright)
                        Text(box.statusText).font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.black.opacity(0.76), in: Capsule()).foregroundStyle(.white).padding(.bottom, 28)
                }
            }
        }
        .onAppear { box.start(session: session) }
        .onDisappear { model.updateResume(item: session.item, seconds: box.current, duration: box.duration); box.stop() }
        .preferredColorScheme(.dark)
    }
}

private struct VLCVideoSurface: UIViewRepresentable {
    let player: VLCMediaPlayer
    func makeUIView(context: Context) -> UIView { let view = UIView(frame: .zero); view.backgroundColor = .black; player.drawable = view; return view }
    func updateUIView(_ uiView: UIView, context: Context) { if (player.drawable as AnyObject?) !== uiView { player.drawable = uiView } }
}

@MainActor
final class PlayerBox: ObservableObject {
    enum Engine { case apple, vlc }
    let player = AVPlayer()
    let vlcPlayer = VLCMediaPlayer()
    @Published var statusText = ""
    @Published var engine: Engine = .apple

    private var token: Any?
    private var watchdog: Timer?
    private var vlcTimer: Timer?
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
    private var vlcTried = Set<String>()
    private var preferredEngine = "auto"
    private var bufferProfile = "balanced"

    var current: Double = 0
    var duration: Double = 0

    func start(session: PlaybackSession) {
        stop()
        candidates = session.candidates
        candidateIndex = 0
        retriesOnCurrent = 0
        isLive = session.item.kind == .live
        requestedStart = isLive ? 0 : session.start
        preferredEngine = session.preferredEngine
        bufferProfile = session.bufferProfile
        current = requestedStart; duration = 0; vlcTried.removeAll(); installTimeObserver()
        guard let first = candidates.first else { statusText = "لا يوجد مسار تشغيل صالح"; return }
        if preferredEngine == "vlc" || (preferredEngine == "auto" && shouldPreferVLC(first)) { playVLC(url: first, keepPosition: false) }
        else { playApple(at: 0, keepPosition: false) }
        watchdog = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in Task { @MainActor in self?.checkHealth() } }
    }

    private var liveAppleBuffer: Double { bufferProfile == "fast" ? 1 : (bufferProfile == "stable" ? 5 : 2) }
    private var vodAppleBuffer: Double { bufferProfile == "fast" ? 4 : (bufferProfile == "stable" ? 15 : 8) }
    private var vlcNetworkCache: Int { bufferProfile == "fast" ? (isLive ? 650 : 1200) : (bufferProfile == "stable" ? (isLive ? 2400 : 5000) : (isLive ? 1200 : 2500)) }

    private func shouldPreferVLC(_ url: URL) -> Bool { ["ts", "mkv", "avi", "webm", "flv", "mpeg", "mpg"].contains(url.pathExtension.lowercased()) }

    private func installTimeObserver() {
        token = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, self.engine == .apple else { return }
                let now = time.seconds
                if now.isFinite { self.current = now; if self.lastPosition < 0 || now - self.lastPosition >= 0.75 { self.lastPosition = now; self.lastAdvanceAt = Date(); self.statusText = ""; self.retriesOnCurrent = 0 } }
                let total = self.player.currentItem?.duration.seconds ?? 0; if total.isFinite && total > 0 { self.duration = total }
            }
        }
    }

    private func makeItem(url: URL) -> AVPlayerItem {
        let headers = ["User-Agent": "BLOFY PLAYER/2.0", "Accept": "*/*", "Connection": "keep-alive"]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = isLive ? liveAppleBuffer : vodAppleBuffer
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        return item
    }

    private func playApple(at index: Int, keepPosition: Bool) {
        guard candidates.indices.contains(index), !switching else { if !candidates.indices.contains(index) { tryVLCFallback() }; return }
        switching = true; engine = .apple; vlcPlayer.stop(); vlcTimer?.invalidate(); vlcTimer = nil; candidateIndex = index
        let resume = isLive ? 0 : (keepPosition ? current : requestedStart); let url = candidates[index]
        openedAt = Date(); lastAdvanceAt = Date(); lastPosition = -1; statusText = index == 0 ? "جاري التشغيل…" : "تجربة مسار بديل…"
        statusObservation?.invalidate(); if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        let item = makeItem(url: url)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in Task { @MainActor in guard let self else { return }; if item.status == .failed { self.handleAppleFailure() } } }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in Task { @MainActor in self?.handleAppleFailure() } }
        player.pause(); player.replaceCurrentItem(with: item)
        if resume > 0 { player.seek(to: CMTime(seconds: resume, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) }
        player.play(); switching = false
    }

    private func handleAppleFailure() {
        guard engine == .apple, !switching else { return }
        if preferredEngine == "apple" && candidateIndex + 1 >= candidates.count { statusText = "تعذر التشغيل بمحرك Apple"; return }
        if retriesOnCurrent < 1 { retriesOnCurrent += 1; statusText = "إعادة محاولة…"; playApple(at: candidateIndex, keepPosition: true) }
        else if candidateIndex + 1 < candidates.count {
            retriesOnCurrent = 0; let next = candidates[candidateIndex + 1]
            if preferredEngine != "apple" && shouldPreferVLC(next) { candidateIndex += 1; playVLC(url: next, keepPosition: true) }
            else { playApple(at: candidateIndex + 1, keepPosition: true) }
        } else if preferredEngine != "apple" { tryVLCFallback() }
        else { statusText = "تعذر تشغيل هذا المحتوى" }
    }

    private func tryVLCFallback() {
        guard preferredEngine != "apple" else { statusText = "تعذر تشغيل هذا المحتوى"; return }
        let ordered = Array(candidates.dropFirst(candidateIndex)) + Array(candidates.prefix(candidateIndex))
        if let next = ordered.first(where: { !vlcTried.contains($0.absoluteString) }) { playVLC(url: next, keepPosition: true) }
        else { statusText = "تعذر تشغيل هذا المحتوى" }
    }

    private func playVLC(url: URL, keepPosition: Bool) {
        switching = true; engine = .vlc; player.pause(); player.replaceCurrentItem(with: nil); statusObservation?.invalidate(); statusObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        vlcTried.insert(url.absoluteString); openedAt = Date(); lastAdvanceAt = Date(); lastPosition = -1; statusText = "تشغيل بمحرك VLC…"
        guard let media = VLCMedia(url: url) else { switching = false; tryVLCFallback(); return }
        media.addOptions(["network-caching": vlcNetworkCache, "http-user-agent": "BLOFY PLAYER/2.0"])
        vlcPlayer.media = media; vlcPlayer.play()
        if !isLive { let seek = keepPosition ? current : requestedStart; if seek > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.vlcPlayer.time = VLCTime(int: Int32(seek * 1000)) } } }
        vlcTimer?.invalidate(); vlcTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.pollVLC() } }; switching = false
    }

    private func pollVLC() {
        guard engine == .vlc else { return }
        let millis = Double(vlcPlayer.time.intValue)
        if millis >= 0 { let seconds = millis / 1000; current = seconds; if lastPosition < 0 || seconds - lastPosition >= 0.75 { lastPosition = seconds; lastAdvanceAt = Date(); statusText = "" } }
        if let media = vlcPlayer.media { let total = Double(media.length.intValue) / 1000; if total.isFinite && total > 0 { duration = total } }
    }

    private func checkHealth() {
        guard !switching else { return }; let now = Date()
        if engine == .apple {
            guard player.currentItem != nil else { return }
            let startupWaiting = lastPosition < 0 && now.timeIntervalSince(openedAt) >= 10
            let stalled = player.timeControlStatus == .waitingToPlayAtSpecifiedRate && now.timeIntervalSince(lastAdvanceAt) >= 12
            let silentLiveStall = isLive && player.timeControlStatus == .playing && now.timeIntervalSince(lastAdvanceAt) >= 12
            if startupWaiting || stalled || silentLiveStall { handleAppleFailure() }
        } else if now.timeIntervalSince(lastAdvanceAt) >= (isLive ? 14 : 18) { vlcPlayer.stop(); tryVLCFallback() }
    }

    func stop() {
        watchdog?.invalidate(); watchdog = nil; vlcTimer?.invalidate(); vlcTimer = nil; statusObservation?.invalidate(); statusObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        if let token { player.removeTimeObserver(token) }; token = nil
        player.pause(); player.replaceCurrentItem(with: nil); vlcPlayer.stop(); candidates = []; switching = false
    }
}
