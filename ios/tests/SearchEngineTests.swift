import Foundation

@main struct SearchEngineTests {
    static func item(_ id: String, _ name: String, kind: ContentKind = .movie) -> MediaItem {
        MediaItem(id: id, remoteID: id, kind: kind, name: name, categoryID: "all")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            print("FAIL: \(message)")
            exit(1)
        }
    }

    static func main() async {
        let engine = MediaSearchEngine()
        let sourceA = UUID()
        let sourceB = UUID()
        let items = [
            item("1", "SSC Sports 1", kind: .live),
            item("2", "Sports Arabia", kind: .live),
            item("3", "The Sport Movie"),
            item("4", "أفلام عربية"),
            item("5", "مسلسل الاختبار", kind: .series)
        ]

        let oneLetter = await engine.search(items: items, query: "s", sourceID: sourceA, limit: 10)
        expect(oneLetter.map(\.id).prefix(2) == ["1", "2"], "prefix matches must rank ahead of contains matches")

        let arabic = await engine.search(items: items, query: "افلام", sourceID: sourceA, limit: 10)
        expect(arabic.first?.id == "4", "Arabic normalization must ignore hamza variants")

        let limited = await engine.search(items: items, query: "sport", sourceID: sourceA, limit: 2)
        expect(limited.count == 2, "search result limit must be enforced")

        let renamedSameID = [item("1", "News Channel", kind: .live)]
        let sameSourceRefresh = await engine.search(items: renamedSameID, query: "news", sourceID: sourceA, limit: 10)
        expect(sameSourceRefresh.first?.name == "News Channel", "same-source renamed items must invalidate their cached normalized name")

        let switchedSource = [item("1", "Cinema One")]
        let newSource = await engine.search(items: switchedSource, query: "cinema", sourceID: sourceB, limit: 10)
        expect(newSource.first?.name == "Cinema One", "server switches must not reuse another server's cached names")

        await engine.reset()
        let afterReset = await engine.search(items: items, query: "مسلسل", sourceID: sourceA, limit: 10)
        expect(afterReset.first?.id == "5", "search must remain usable after explicit reset")

        print("RESULT: Search engine scenarios passed.")
    }
}
