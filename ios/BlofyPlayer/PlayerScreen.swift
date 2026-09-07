import SwiftUI
import AVKit
import AVFoundation
import VLCKit

struct PlayerTrack: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct PlayerScreen: View {
    @EnvironmentObject var model: AppModel
    let session: PlaybackSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var box = PlayerBox()
    @State private var controlsVisible = true
    @State private var showAudio = false
    @State private var showSubtitles = false
    @State private var showSpeed = false
    @AppStorage("showPlayerEngineBadge") private var showEngineBadge = true
    @AppStorage("videoAspectMode") private var aspectMode = "fit"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if box.engine == .vlc {
                VLCVideoSurface(player: box.vlcPlayer).ignoresSafeArea()
            } else {
                AppleVideoSurface(player: box.player, aspectMode: aspectMode).ignoresSafeArea()
            }

            Color.clear.contentShape(Rectangle()).onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) { controlsVisible.toggle() }
            }

            if controlsVisible {
                LinearGradient(colors: [.black.opacity(0.72), .clear, .black.opacity(0.84)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea().allowsHitTesting(false)
                PlayerControlsOverlay(box: box, item: session.item, showAudio: $showAudio, showSubtitles: $showSubtitles, showSpeed: $showSpeed, showEngineBadge: showEngineBadge, dismiss: dismiss)
                    .transition(.opacity)
            }

            if !box.statusText.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 9) {
                        ProgressView().tint(BlofyTheme.purpleBright)
                        Text(box.statusText).font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule()).foregroundStyle(.white).padding(.bottom, 96)
                }.allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showAudio) {
            TrackSheet(title: "مسار الصوت", icon: "speaker.wave.2.fill", tracks: box.audioTracks, selected: box.selectedAudioTrack) { box.selectAudio($0) }
        }
        .sheet(isPresented: $showSubtitles) {
            TrackSheet(title: "الترجمة", icon: "captions.bubble.fill", tracks: box.subtitleTracks, selected: box.selectedSubtitleTrack, includesOff: true) { box.selectSubtitle($0) }
        }
        .sheet(isPresented: $showSpeed) { SpeedSheet(box: box) }
        .onAppear { box.start(session: session) }
        .onDisappear {
            model.updateResume(item: session.item, seconds: box.current, duration: box.duration)
            box.stop()
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
    }
}

private struct PlayerControlsOverlay: View {
    @ObservedObject var box: PlayerBox
    let item: MediaItem
    @Binding var showAudio: Bool
    @Binding var showSubtitles: Bool
    @Binding var showSpeed: Bool
    let showEngineBadge: Bool
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: { PlayerCircleButton(icon: "xmark") }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.headline.bold()).lineLimit(1)
                    Text(item.kind == .live ? "بث مباشر" : item.kind.title).font(.caption).foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                if showEngineBadge {
                    HStack(spacing: 6) {
                        Circle().fill(box.engine == .vlc ? BlofyTheme.mint : BlofyTheme.purpleBright).frame(width: 7, height: 7)
                        Text(box.engine == .vlc ? "VLC" : "APPLE").font(.caption2.bold())
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                }
            }.padding(.horizontal, 16).padding(.top, 10)

            Spacer()

            HStack(spacing: 30) {
                if item.kind != .live { Button { box.seek(by: -10) } label: { PlayerMainButton(icon: "gobackward.10", size: 28) } }
                Button { box.togglePlay() } label: {
                    Image(systemName: box.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 31, weight: .bold)).frame(width: 72, height: 72)
                        .background(.white, in: Circle()).foregroundStyle(.black).shadow(color: .black.opacity(0.4), radius: 12)
                }.buttonStyle(.plain)
                if item.kind != .live { Button { box.seek(by: 10) } label: { PlayerMainButton(icon: "goforward.10", size: 28) } }
            }

            Spacer()

            VStack(spacing: 12) {
                if item.kind != .live && box.duration > 0 {
                    VStack(spacing: 5) {
                        Slider(value: Binding(get: { box.current }, set: { box.seek(to: $0) }), in: 0...max(box.duration, 1)).tint(BlofyTheme.purpleBright)
                        HStack {
                            Text(playerTime(box.current)); Spacer(); Text("-" + playerTime(max(0, box.duration - box.current)))
                        }.font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.66))
                    }
                }

                HStack(spacing: 10) {
                    PlayerToolButton(title: "صوت", icon: "speaker.wave.2.fill", badge: box.audioTracks.count > 1 ? "\(box.audioTracks.count)" : nil) { box.refreshTracks(); showAudio = true }
                    PlayerToolButton(title: "ترجمة", icon: "captions.bubble.fill", badge: box.subtitleTracks.isEmpty ? nil : "\(box.subtitleTracks.count)") { box.refreshTracks(); showSubtitles = true }
                    if item.kind != .live { PlayerToolButton(title: "السرعة", icon: "speedometer", badge: String(format: "%.2fx", box.rate)) { showSpeed = true } }
                    PlayerToolButton(title: "تحديث", icon: "arrow.clockwise") { box.refreshTracks() }
                }
            }
            .padding(14).background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 14).padding(.bottom, 16)
        }.foregroundStyle(.white)
    }
}

private struct PlayerCircleButton: View {
    let icon: String
    var body: some View { Image(systemName: icon).font(.system(size: 16, weight: .bold)).frame(width: 40, height: 40).background(.black.opacity(0.58), in: Circle()).foregroundStyle(.white) }
}

private struct PlayerMainButton: View {
    let icon: String
    let size: CGFloat
    var body: some View { Image(systemName: icon).font(.system(size: size, weight: .semibold)).frame(width: 54, height: 54).background(.black.opacity(0.44), in: Circle()).foregroundStyle(.white) }
}

private struct PlayerToolButton: View {
    let title: String
    let icon: String
    var badge: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold)).frame(width: 38, height: 30)
                    if let badge { Text(badge).font(.system(size: 8, weight: .black)).padding(4).background(BlofyTheme.purpleBright, in: Circle()).offset(x: 7, y: -5) }
                }
                Text(title).font(.caption2.bold())
            }.frame(maxWidth: .infinity).foregroundStyle(.white)
        }.buttonStyle(.plain)
    }
}

private struct TrackSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let icon: String
    let tracks: [PlayerTrack]
    let selected: Int
    var includesOff: Bool = false
    let select: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                if includesOff { Button { select(-1); dismiss() } label: { TrackRow(name: "إيقاف الترجمة", selected: selected == -1, icon: "captions.bubble") } }
                ForEach(tracks) { track in Button { select(track.id); dismiss() } label: { TrackRow(name: track.name, selected: selected == track.id, icon: icon) } }
                if tracks.isEmpty { Text("لا توجد مسارات متاحة في هذا المحتوى").foregroundStyle(BlofyTheme.textMuted) }
            }
            .scrollContentBackground(.hidden).background(BlofyTheme.backgroundGradient)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}

private struct TrackRow: View {
    let name: String
    let selected: Bool
    let icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(BlofyTheme.purpleSoft).frame(width: 26)
            Text(name).foregroundStyle(.white); Spacer()
            if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(BlofyTheme.mint) }
        }
    }
}

private struct SpeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var box: PlayerBox
    private let speeds: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]
    var body: some View {
        NavigationStack {
            List(speeds, id: \.self) { speed in
                Button { box.setRate(speed); dismiss() } label: {
                    HStack { Text(String(format: "%.2fx", speed)); Spacer(); if abs(box.rate - speed) < 0.01 { Image(systemName: "checkmark.circle.fill").foregroundStyle(BlofyTheme.mint) } }
                }.foregroundStyle(.white)
            }.scrollContentBackground(.hidden).background(BlofyTheme.backgroundGradient).navigationTitle("سرعة التشغيل")
        }.preferredColorScheme(.dark)
    }
}

private struct VLCVideoSurface: UIViewRepresentable {
    let player: VLCMediaPlayer
    func makeUIView(context: Context) -> UIView { let view = UIView(frame: .zero); view.backgroundColor = .black; player.drawable = view; return view }
    func updateUIView(_ uiView: UIView, context: Context) { if (player.drawable as AnyObject?) !== uiView { player.drawable = uiView } }
}

private final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private struct AppleVideoSurface: UIViewRepresentable {
    let player: AVPlayer
    let aspectMode: String
    func makeUIView(context: Context) -> PlayerLayerView { let view = PlayerLayerView(frame: .zero); view.backgroundColor = .black; view.playerLayer.player = player; apply(view.playerLayer); return view }
    func updateUIView(_ uiView: PlayerLayerView, context: Context) { uiView.playerLayer.player = player; apply(uiView.playerLayer) }
    private func apply(_ layer: AVPlayerLayer) { layer.videoGravity = aspectMode == "fill" || aspectMode == "16:9" ? .resizeAspectFill : .resizeAspect }
}

@MainActor
final class PlayerBox: ObservableObject {
    enum Engine { case apple, vlc }
    let player = AVPlayer()
    let vlcPlayer = VLCMediaPlayer()

    @Published var statusText = ""
    @Published var engine: Engine = .apple
    @Published var isPlaying = false
    @Published var current: Double = 0
    @Published var duration: Double = 0
    @Published var rate: Float = 1
    @Published var audioTracks: [PlayerTrack] = []
    @Published var subtitleTracks: [PlayerTrack] = []
    @Published var selectedAudioTrack = -1
    @Published var selectedSubtitleTrack = -1

    @AppStorage("preferredAudioLanguage") private var preferredAudioLanguage = "auto"
    @AppStorage("preferredSubtitleLanguage") private var preferredSubtitleLanguage = "auto"
    @AppStorage("autoEnableSubtitles") private var autoEnableSubtitles = false
    @AppStorage("subtitleScale") private var subtitleScale = 1.0
    @AppStorage("subtitleDelayMs") private var subtitleDelayMs = 0.0
    @AppStorage("defaultPlaybackRate") private var defaultPlaybackRate = 1.0
    @AppStorage("rememberTrackSelection") private var rememberTrackSelection = true
    @AppStorage("lastAudioTrackName") private var lastAudioTrackName = ""
    @AppStorage("lastSubtitleTrackName") private var lastSubtitleTrackName = ""

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
    private var didApplyTrackPreferences = false

    func start(session: PlaybackSession) {
        stop()
        candidates = session.candidates; candidateIndex = 0; retriesOnCurrent = 0; isLive = session.item.kind == .live
        requestedStart = isLive ? 0 : session.start; preferredEngine = session.preferredEngine; bufferProfile = session.bufferProfile
        current = requestedStart; duration = 0; rate = Float(defaultPlaybackRate); vlcTried.removeAll(); didApplyTrackPreferences = false
        installTimeObserver()
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
        token = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, self.engine == .apple else { return }
                let now = time.seconds
                if now.isFinite { self.current = now; if self.lastPosition < 0 || now - self.lastPosition >= 0.4 { self.lastPosition = now; self.lastAdvanceAt = Date(); self.statusText = ""; self.retriesOnCurrent = 0 } }
                let total = self.player.currentItem?.duration.seconds ?? 0; if total.isFinite && total > 0 { self.duration = total }
                self.isPlaying = self.player.timeControlStatus == .playing
            }
        }
    }

    private func makeItem(url: URL) -> AVPlayerItem {
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": "BLOFY PLAYER/2.0", "Accept": "*/*", "Connection": "keep-alive"]])
        let item = AVPlayerItem(asset: asset); item.preferredForwardBufferDuration = isLive ? liveAppleBuffer : vodAppleBuffer; item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        return item
    }

    private func playApple(at index: Int, keepPosition: Bool) {
        guard candidates.indices.contains(index), !switching else { if !candidates.indices.contains(index) { tryVLCFallback() }; return }
        switching = true; engine = .apple; vlcPlayer.stop(); vlcTimer?.invalidate(); vlcTimer = nil; candidateIndex = index; audioTracks = []; subtitleTracks = []
        let resume = isLive ? 0 : (keepPosition ? current : requestedStart); let url = candidates[index]
        openedAt = Date(); lastAdvanceAt = Date(); lastPosition = -1; statusText = index == 0 ? "جاري التشغيل…" : "تجربة مسار بديل…"
        statusObservation?.invalidate(); if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        let item = makeItem(url: url)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in Task { @MainActor in guard let self else { return }; if item.status == .failed { self.handleAppleFailure() } else if item.status == .readyToPlay { self.refreshTracks(); self.applyTrackPreferencesIfNeeded() } } }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in Task { @MainActor in self?.handleAppleFailure() } }
        player.pause(); player.replaceCurrentItem(with: item)
        if resume > 0 { player.seek(to: CMTime(seconds: resume, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) }
        player.playImmediately(atRate: rate); isPlaying = true; switching = false
    }

    private func handleAppleFailure() {
        guard engine == .apple, !switching else { return }
        if preferredEngine == "apple" && candidateIndex + 1 >= candidates.count { statusText = "تعذر التشغيل بمحرك Apple"; return }
        if retriesOnCurrent < 1 { retriesOnCurrent += 1; statusText = "إعادة محاولة…"; playApple(at: candidateIndex, keepPosition: true) }
        else if candidateIndex + 1 < candidates.count {
            retriesOnCurrent = 0; let next = candidates[candidateIndex + 1]
            if preferredEngine != "apple" && shouldPreferVLC(next) { candidateIndex += 1; playVLC(url: next, keepPosition: true) }
            else { playApple(at: candidateIndex + 1, keepPosition: true) }
        } else if preferredEngine != "apple" { tryVLCFallback() } else { statusText = "تعذر تشغيل هذا المحتوى" }
    }

    private func tryVLCFallback() {
        guard preferredEngine != "apple" else { statusText = "تعذر تشغيل هذا المحتوى"; return }
        let ordered = Array(candidates.dropFirst(candidateIndex)) + Array(candidates.prefix(candidateIndex))
        if let next = ordered.first(where: { !vlcTried.contains($0.absoluteString) }) { playVLC(url: next, keepPosition: true) }
        else { statusText = "تعذر تشغيل هذا المحتوى" }
    }

    private func playVLC(url: URL, keepPosition: Bool) {
        switching = true; engine = .vlc; player.pause(); player.replaceCurrentItem(with: nil); statusObservation?.invalidate(); statusObservation = nil; audioTracks = []; subtitleTracks = []
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        vlcTried.insert(url.absoluteString); openedAt = Date(); lastAdvanceAt = Date(); lastPosition = -1; statusText = "تشغيل بمحرك VLC…"
        guard let media = VLCMedia(url: url) else { switching = false; tryVLCFallback(); return }
        media.addOptions(["network-caching": vlcNetworkCache, "http-user-agent": "BLOFY PLAYER/2.0"])
        vlcPlayer.media = media; vlcPlayer.rate = rate; vlcPlayer.currentSubTitleFontScale = Float(subtitleScale); vlcPlayer.currentVideoSubTitleDelay = Int(subtitleDelayMs * 1000); vlcPlayer.play(); isPlaying = true
        if !isLive { let seek = keepPosition ? current : requestedStart; if seek > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.vlcPlayer.time = VLCTime(int: Int32(seek * 1000)) } } }
        vlcTimer?.invalidate(); vlcTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.pollVLC() } }; switching = false
    }

    private func pollVLC() {
        guard engine == .vlc else { return }
        let millis = Double(vlcPlayer.time.intValue)
        if millis >= 0 { let seconds = millis / 1000; current = seconds; if lastPosition < 0 || seconds - lastPosition >= 0.5 { lastPosition = seconds; lastAdvanceAt = Date(); statusText = "" } }
        if let media = vlcPlayer.media { let total = Double(media.length.intValue) / 1000; if total.isFinite && total > 0 { duration = total } }
        isPlaying = vlcPlayer.isPlaying
        if audioTracks.isEmpty && subtitleTracks.isEmpty && millis > 0 { refreshTracks(); applyTrackPreferencesIfNeeded() }
    }

    func togglePlay() {
        if engine == .apple { if player.timeControlStatus == .playing { player.pause(); isPlaying = false } else { player.playImmediately(atRate: rate); isPlaying = true } }
        else { if vlcPlayer.isPlaying { vlcPlayer.pause(); isPlaying = false } else { vlcPlayer.play(); vlcPlayer.rate = rate; isPlaying = true } }
    }

    func seek(by delta: Double) { guard !isLive else { return }; seek(to: max(0, duration > 0 ? min(duration, current + delta) : current + delta)) }
    func seek(to seconds: Double) {
        guard !isLive else { return }; let target = max(0, duration > 0 ? min(duration, seconds) : seconds); current = target
        if engine == .apple { player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: CMTime(seconds: 0.25, preferredTimescale: 600), toleranceAfter: CMTime(seconds: 0.25, preferredTimescale: 600)) }
        else { vlcPlayer.time = VLCTime(int: Int32(target * 1000)) }
    }

    func setRate(_ value: Float) { rate = value; if engine == .apple { if isPlaying { player.playImmediately(atRate: value) } } else { vlcPlayer.rate = value } }

    func refreshTracks() {
        if engine == .vlc {
            let rawAudio: [VLCMediaPlayerTrack] = vlcPlayer.audioTracks
            audioTracks = rawAudio.enumerated().map { PlayerTrack(id: $0.offset, name: cleanTrackName($0.element.trackName, fallback: "صوت \($0.offset + 1)")) }
            selectedAudioTrack = rawAudio.firstIndex(where: { $0.isSelectedExclusively }) ?? -1

            let rawText: [VLCMediaPlayerTrack] = vlcPlayer.textTracks
            subtitleTracks = rawText.enumerated().filter { !isDisabledTrack($0.element.trackName) }.map { PlayerTrack(id: $0.offset, name: cleanTrackName($0.element.trackName, fallback: "ترجمة \($0.offset + 1)")) }
            if let selected = rawText.firstIndex(where: { $0.isSelectedExclusively && !isDisabledTrack($0.trackName) }) { selectedSubtitleTrack = selected } else { selectedSubtitleTrack = -1 }
        } else if let item = player.currentItem {
            if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
                audioTracks = group.options.enumerated().map { PlayerTrack(id: $0.offset, name: cleanTrackName($0.element.displayName, fallback: "صوت \($0.offset + 1)")) }
                if let selected = item.currentMediaSelection.selectedMediaOption(in: group), let idx = group.options.firstIndex(of: selected) { selectedAudioTrack = idx }
            }
            if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                subtitleTracks = group.options.enumerated().map { PlayerTrack(id: $0.offset, name: cleanTrackName($0.element.displayName, fallback: "ترجمة \($0.offset + 1)")) }
                if let selected = item.currentMediaSelection.selectedMediaOption(in: group), let idx = group.options.firstIndex(of: selected) { selectedSubtitleTrack = idx } else { selectedSubtitleTrack = -1 }
            }
        }
    }

    func selectAudio(_ id: Int) {
        if engine == .vlc {
            let tracks: [VLCMediaPlayerTrack] = vlcPlayer.audioTracks
            if tracks.indices.contains(id) { tracks[id].isSelectedExclusively = true }
        } else if let item = player.currentItem, let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible), group.options.indices.contains(id) { item.select(group.options[id], in: group) }
        selectedAudioTrack = id
        if let name = audioTracks.first(where: { $0.id == id })?.name { lastAudioTrackName = name }
    }

    func selectSubtitle(_ id: Int) {
        if engine == .vlc {
            let tracks: [VLCMediaPlayerTrack] = vlcPlayer.textTracks
            if id < 0 {
                if let disabled = tracks.first(where: { isDisabledTrack($0.trackName) }) { disabled.isSelectedExclusively = true }
                else { tracks.forEach { $0.isSelectedExclusively = false } }
            } else if tracks.indices.contains(id) { tracks[id].isSelectedExclusively = true }
            vlcPlayer.currentVideoSubTitleDelay = Int(subtitleDelayMs * 1000); vlcPlayer.currentSubTitleFontScale = Float(subtitleScale)
        } else if let item = player.currentItem, let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            if id < 0 { item.select(nil, in: group) } else if group.options.indices.contains(id) { item.select(group.options[id], in: group) }
        }
        selectedSubtitleTrack = id
        if let name = subtitleTracks.first(where: { $0.id == id })?.name { lastSubtitleTrackName = name }
    }

    private func applyTrackPreferencesIfNeeded() {
        guard !didApplyTrackPreferences else { return }; didApplyTrackPreferences = true; refreshTracks()
        if rememberTrackSelection, !lastAudioTrackName.isEmpty, let track = audioTracks.first(where: { $0.name == lastAudioTrackName }) { selectAudio(track.id) }
        else if let track = preferredTrack(in: audioTracks, language: preferredAudioLanguage) { selectAudio(track.id) }
        if autoEnableSubtitles {
            if rememberTrackSelection, !lastSubtitleTrackName.isEmpty, let track = subtitleTracks.first(where: { $0.name == lastSubtitleTrackName }) { selectSubtitle(track.id) }
            else if let track = preferredTrack(in: subtitleTracks, language: preferredSubtitleLanguage) { selectSubtitle(track.id) }
        } else { selectSubtitle(-1) }
    }

    private func preferredTrack(in tracks: [PlayerTrack], language: String) -> PlayerTrack? {
        guard !tracks.isEmpty else { return nil }
        if language == "first" || language == "auto" { return tracks.first }
        let tokens = language == "ar" ? ["arab", "عرب"] : ["english", "eng", "انجل", "إنجل"]
        return tracks.first { track in tokens.contains { track.name.lowercased().contains($0) } } ?? tracks.first
    }

    private func isDisabledTrack(_ name: String) -> Bool { let s = name.lowercased(); return s.contains("disable") || s == "off" || s.contains("deaktiv") }
    private func cleanTrackName(_ name: String, fallback: String) -> String { let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines); return trimmed.isEmpty ? fallback : trimmed }

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
        player.pause(); player.replaceCurrentItem(with: nil); vlcPlayer.stop(); candidates = []; switching = false; isPlaying = false
    }
}

private func playerTime(_ seconds: Double) -> String {
    guard seconds.isFinite && seconds >= 0 else { return "00:00" }
    let value = Int(seconds.rounded(.down)); let h = value / 3600; let m = (value % 3600) / 60; let s = value % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}
