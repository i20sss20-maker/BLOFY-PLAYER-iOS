import Foundation

extension AppModel {
    func makePlaybackSession(for item: MediaItem) throws -> PlaybackSession {
        guard let provider = selected else { throw AppError.message("لا توجد قائمة محددة") }
        let candidates = try PlaybackResolver.candidates(provider: provider, item: item)
        return PlaybackSession(
            item: item,
            candidates: candidates,
            start: resume[item.id]?.seconds ?? 0,
            preferredEngine: preferredEngine,
            bufferProfile: bufferProfile
        )
    }
}
