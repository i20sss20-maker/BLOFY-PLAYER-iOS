import Foundation

enum CatalogCacheStore {
    private static let directoryName = "CatalogCache"
    private static let staleAge: TimeInterval = 30 * 24 * 60 * 60

    private static var rootURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("BLOFY", isDirectory: true).appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func fileURL(for playlistID: UUID) -> URL? {
        rootURL?.appendingPathComponent("\(playlistID.uuidString).json", isDirectory: false)
    }

    static func load(for playlistID: UUID) -> Data? {
        guard let url = fileURL(for: playlistID) else { return nil }
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]), !data.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        touchAccessDate(url)
        return data
    }

    static func save(_ data: Data, for playlistID: UUID) {
        guard !data.isEmpty, let root = rootURL, let url = fileURL(for: playlistID) else { return }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            values.contentAccessDate = Date()
            var mutableURL = url
            try? mutableURL.setResourceValues(values)
            pruneStaleFiles(in: root, excluding: url)
        } catch {
            // Catalog cache is recoverable from the provider; a disk write failure must not break playback.
        }
    }

    static func remove(for playlistID: UUID) {
        guard let url = fileURL(for: playlistID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func touchAccessDate(_ url: URL) {
        var values = URLResourceValues()
        values.contentAccessDate = Date()
        var mutableURL = url
        try? mutableURL.setResourceValues(values)
    }

    private static func pruneStaleFiles(in root: URL, excluding activeURL: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentAccessDateKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-staleAge)
        for url in files where url != activeURL && url.pathExtension.lowercased() == "json" {
            guard let values = try? url.resourceValues(forKeys: [.contentAccessDateKey, .contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            let lastUsed = values.contentAccessDate ?? values.contentModificationDate ?? .distantPast
            if lastUsed < cutoff { try? FileManager.default.removeItem(at: url) }
        }
    }
}
