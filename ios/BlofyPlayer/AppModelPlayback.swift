import Foundation

extension AppModel {
    func makePlaybackSession(for item: MediaItem) throws -> PlaybackSession {
        guard let provider = selected else { throw AppError.message("لا توجد قائمة محددة") }
        let candidates = try PlaybackResolver.candidates(provider: provider, item: item)

        // Apple is excellent for native HLS/live playback, while VLC is substantially
        // more tolerant of Xtream VOD containers/codecs. Keep manual engine choices intact.
        let engine: String
        if preferredEngine == "auto" && (item.kind == .movie || item.kind == .episode) {
            engine = "vlc"
        } else {
            engine = preferredEngine
        }

        return PlaybackSession(
            item: item,
            candidates: candidates,
            start: resume[item.id]?.seconds ?? 0,
            preferredEngine: engine,
            bufferProfile: bufferProfile
        )
    }
}
