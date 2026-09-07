import Foundation

enum ContentKind: String, Codable, CaseIterable, Identifiable {
    case live, movie, series, episode
    var id: String { rawValue }
    var title: String {
        switch self {
        case .live: return "البث المباشر"
        case .movie: return "الأفلام"
        case .series: return "المسلسلات"
        case .episode: return "الحلقات"
        }
    }
    var icon: String {
        switch self {
        case .live: return "tv.fill"
        case .movie: return "film.fill"
        case .series: return "play.rectangle.on.rectangle.fill"
        case .episode: return "play.circle.fill"
        }
    }
}

struct Playlist: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var type: String
    var url: String
    var username: String = ""
    var password: String = ""
    var liveFormat: String = "ts"
}

struct MediaCategory: Identifiable, Codable, Hashable {
    var id: String { "\(kind.rawValue):\(key)" }
    let key: String
    let name: String
    let kind: ContentKind
}

struct MediaItem: Identifiable, Codable, Hashable {
    let id: String
    let remoteID: String
    let kind: ContentKind
    let name: String
    let categoryID: String
    var poster: String = ""
    var container: String = "mp4"
    var directURL: String = ""
    var plot: String = ""
    var rating: String = ""
    var seriesID: String = ""
    var season: Int = 0
    var episode: Int = 0
}

struct ResumeEntry: Codable {
    var seconds: Double
    var duration: Double
    var item: MediaItem
    var updatedAt: Date = Date()
}

struct PlaybackSession: Identifiable {
    let id = UUID()
    let item: MediaItem
    let candidates: [URL]
    let start: Double
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

func normalizedSearch(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ar"))
        .replacingOccurrences(of: "أ", with: "ا")
        .replacingOccurrences(of: "إ", with: "ا")
        .replacingOccurrences(of: "آ", with: "ا")
        .replacingOccurrences(of: "ى", with: "ي")
        .replacingOccurrences(of: "ـ", with: "")
}
