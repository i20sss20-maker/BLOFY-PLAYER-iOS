import Foundation

enum CatalogCacheStore {
    private static let directoryName = "CatalogCache"

    private static var rootURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("BLOFY", isDirectory: true).appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func fileURL(for playlistID: UUID) -> URL? {
        rootURL?.appendingPathComponent("\(playlistID.uuidString).json", isDirectory: false)
    }

    static func load(for playlistID: UUID) -> Data? {
        guard let url = fileURL(for: playlistID) else { return nil }
        return try? Data(contentsOf: url, options: [.mappedIfSafe])
    }

    static func save(_ data: Data, for playlistID: UUID) {
        guard let root = rootURL, let url = fileURL(for: playlistID) else { return }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = url
            try? mutableURL.setResourceValues(values)
        } catch {
            // Catalog cache is recoverable from the provider; a disk write failure must not break playback.
        }
    }

    static func remove(for playlistID: UUID) {
        guard let url = fileURL(for: playlistID) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
