import Foundation

actor MediaSearchEngine {
    static let shared = MediaSearchEngine()

    private struct CachedName {
        let original: String
        let normalized: String
    }

    private var sourceID: UUID?
    private var names: [String: CachedName] = [:]

    func search(
        items: [MediaItem],
        query rawQuery: String,
        sourceID newSourceID: UUID?,
        limit: Int = 120
    ) -> [MediaItem] {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }

        if sourceID != newSourceID {
            sourceID = newSourceID
            names.removeAll(keepingCapacity: false)
        }

        let needle = normalizedSearch(trimmed)
        guard !needle.isEmpty else { return [] }

        var prefixes: [MediaItem] = []
        var contains: [MediaItem] = []
        prefixes.reserveCapacity(min(limit, 48))
        contains.reserveCapacity(limit)

        for item in items {
            if Task.isCancelled { return [] }

            let normalized: String
            if let cached = names[item.id], cached.original == item.name {
                normalized = cached.normalized
            } else {
                normalized = normalizedSearch(item.name)
                names[item.id] = CachedName(original: item.name, normalized: normalized)
            }

            if normalized.hasPrefix(needle) {
                if prefixes.count < limit { prefixes.append(item) }
            } else if contains.count < limit, normalized.contains(needle) {
                contains.append(item)
            }
        }

        if prefixes.count >= limit { return Array(prefixes.prefix(limit)) }
        return prefixes + contains.prefix(limit - prefixes.count)
    }

    func reset() {
        sourceID = nil
        names.removeAll(keepingCapacity: false)
    }
}
