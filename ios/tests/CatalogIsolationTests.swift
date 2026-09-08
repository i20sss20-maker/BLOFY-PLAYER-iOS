import Foundation
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// Compile the production Models/AppModel/AppModelPortal files against controlled
// I/O doubles. This tests model behavior, not SwiftUI, VLCKit, or real servers.
protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}

enum UserDefaults {
    static let suiteName = "BLOFY.ModelRegression.\(UUID().uuidString)"
    static let standard = Foundation.UserDefaults(suiteName: suiteName)!
}

@MainActor enum CatalogCacheStore {
    static var data: [UUID: Data] = [:]
    static func load(for id: UUID) -> Data? { data[id] }
    static func save(_ value: Data, for id: UUID) { data[id] = value }
    static func remove(for id: UUID) { data.removeValue(forKey: id) }
}

@MainActor final class PortalClient {
    static let shared = PortalClient()
    struct ActivationResult { let status: String }
    var remote: [Playlist] = []
    var fail = false
    func checkActivation(deviceID: String, code: String) async throws -> ActivationResult {
        ActivationResult(status: "active")
    }
    func portalPlaylists(deviceID: String, code: String) async throws -> [Playlist] {
        if fail { throw AppError.message("simulated portal outage") }
        return remote
    }
}

@MainActor final class ProviderClient {
    static let shared = ProviderClient()
    typealias Catalog = ([MediaCategory], [MediaItem])
    struct Pending {
        let provider: Playlist
        let cachedItems: [MediaItem]
        let stages: Set<String>
        let progress: @Sendable (Double, String) async -> Void
        let checkpoint: @Sendable ([MediaCategory], [MediaItem], Set<String>, Double, String) async -> Void
        let continuation: CheckedContinuation<Catalog, Error>
    }
    struct Waiter {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }
    var requests: [UUID: [Pending]] = [:]
    private var waiters: [UUID: [Waiter]] = [:]

    func loadCatalog(
        _ provider: Playlist,
        cachedCategories: [MediaCategory] = [],
        cachedItems: [MediaItem] = [],
        completedStages: Set<String> = [],
        progress: @escaping @Sendable (Double, String) async -> Void,
        checkpoint: @escaping @Sendable ([MediaCategory], [MediaItem], Set<String>, Double, String) async -> Void
    ) async throws -> Catalog {
        try await withCheckedThrowingContinuation { continuation in
            requests[provider.id, default: []].append(Pending(provider: provider,
                cachedItems: cachedItems, stages: completedStages, progress: progress,
                checkpoint: checkpoint, continuation: continuation))
            let ready = waiters[provider.id, default: []].filter { $0.count <= requests[provider.id, default: []].count }
            waiters[provider.id]?.removeAll { $0.count <= requests[provider.id, default: []].count }
            for waiter in ready { waiter.continuation.resume() }
        }
    }
    func waitForRequest(_ provider: Playlist, count: Int = 1) async {
        if requests[provider.id, default: []].count >= count { return }
        await withCheckedContinuation { continuation in
            waiters[provider.id, default: []].append(Waiter(count: count, continuation: continuation))
        }
    }
    func sample(_ provider: Playlist, label: String? = nil) -> Catalog {
        let name = label ?? provider.name
        return ([MediaCategory(key: name, name: name, kind: .live)],
                [MediaItem(id: "live:\(name)", remoteID: "1", kind: .live, name: name, categoryID: name)])
    }
    func emit(_ provider: Playlist, index: Int = 0, label: String? = nil) async {
        let request = requests[provider.id]![index]
        let value = sample(provider, label: label)
        await request.progress(0.34, "checkpoint \(provider.name)")
        await request.checkpoint(value.0, value.1, ["live"], 0.34, "checkpoint \(provider.name)")
    }
    func finish(_ provider: Playlist, index: Int = 0, label: String? = nil, fail: Bool = false) {
        let request = requests[provider.id]![index]
        if fail { request.continuation.resume(throwing: AppError.message("stale provider failure")) }
        else { request.continuation.resume(returning: sample(provider, label: label)) }
    }
    func loadEpisodes(series: MediaItem, provider: Playlist) async throws -> [MediaItem] { [] }
    func movieInfo(movie: MediaItem, provider: Playlist) async throws -> MediaItem { movie }
}

@main struct CatalogIsolationTests {
    @MainActor static var passed = 0
    @MainActor static let network = ProviderClient.shared

    @MainActor static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { print("FAIL: \(message)"); exit(1) }
    }
    @MainActor static func done(_ name: String) {
        passed += 1
        print("PASS \(passed): \(name)")
    }
    @MainActor static func setup() -> (AppModel, Playlist, Playlist) {
        UserDefaults.standard.removePersistentDomain(forName: UserDefaults.suiteName)
        CatalogCacheStore.data = [:]
        PortalClient.shared.remote = []
        PortalClient.shared.fail = false
        let a = Playlist(name: "A", type: "xtream", url: "https://a.invalid", username: "test", password: "old")
        let b = Playlist(name: "B", type: "xtream", url: "https://b.invalid", username: "test", password: "other")
        let model = AppModel()
        model.playlists = [a, b]
        model.selected = a
        model.savePlaylists()
        return (model, a, b)
    }
    @MainActor static func start(_ model: AppModel, _ provider: Playlist, count: Int = 1) async -> Task<Void, Never> {
        let task = Task { await model.loadCatalog() }
        await network.waitForRequest(provider, count: count)
        return task
    }

    @MainActor static func switchBeforeReply() async {
        let (model, a, b) = setup()
        let old = await start(model, a)
        model.choose(b)
        expect(!model.loading, "switching playlists must release the loading gate")
        await network.emit(a)
        expect(model.items.isEmpty && model.categories.isEmpty && model.progress == 0,
               "old progress/checkpoint must not populate the newly selected playlist")
        expect(CatalogCacheStore.load(for: b.id) == nil, "old checkpoint must not be stored under the new playlist ID")
        network.finish(a)
        await old.value
        expect(model.selected?.id == b.id && model.items.isEmpty && !model.loading,
               "old completion must not alter the new selection")
        done("switch rejects stale progress, checkpoints, and completion")
    }

    @MainActor static func overlappingRequests(failure: Bool) async {
        let (model, a, b) = setup()
        let old = await start(model, a)
        model.choose(b)
        expect(!model.loading, "new provider must be able to start immediately")
        let fresh = await start(model, b)
        await network.emit(a)
        network.finish(a, fail: failure)
        await old.value
        expect(model.loading && model.error.isEmpty && model.items.isEmpty,
               "stale success/error must not stop or overwrite the new request")
        await network.emit(b)
        network.finish(b)
        await fresh.value
        expect(model.items.first?.name == "B" && !model.loading && model.progress == 1,
               "the new request must finish normally")
        done(failure ? "stale errors cannot stop the new provider" : "overlapping requests remain isolated")
    }

    @MainActor static func addDuringLoad() async {
        let (model, a, _) = setup()
        let old = await start(model, a)
        model.addPlaylist(name: "C", type: "xtream", url: "https://c.invalid", username: "test", password: "new")
        let id = model.selected!.id
        expect(!model.loading && model.selected?.name == "C", "adding a playlist must invalidate the previous load")
        await network.emit(a)
        network.finish(a)
        await old.value
        expect(model.items.isEmpty && CatalogCacheStore.load(for: id) == nil, "adding a playlist must not inherit stale items")
        done("adding a playlist during loading")
    }

    @MainActor static func deleteDuringLoad(last: Bool) async {
        let (model, a, b) = setup()
        if last { model.playlists = [a] }
        let old = await start(model, a)
        model.delete(a)
        expect(!model.loading, "deleting the active playlist must release the loading gate")
        expect(last ? model.selected == nil : model.selected?.id == b.id, "deletion must retain the correct selection")
        await network.emit(a)
        network.finish(a)
        await old.value
        expect(model.items.isEmpty && CatalogCacheStore.load(for: a.id) == nil && CatalogCacheStore.load(for: b.id) == nil,
               "deleted provider callbacks must not recreate cache entries")
        done(last ? "deleting the last playlist during loading" : "deleting the active playlist during loading")
    }

    @MainActor static func unchangedSelection() async {
        let (model, a, b) = setup()
        let task = await start(model, a)
        model.choose(a)
        model.delete(b)
        expect(model.loading, "reselecting the same playlist/deleting another must preserve the active load")
        network.finish(a)
        await task.value
        expect(model.items.first?.name == "A", "the unchanged provider must finish")
        done("unchanged selection preserves valid loading")
    }

    @MainActor static func backgroundResume() async {
        let (model, a, _) = setup()
        let old = await start(model, a)
        await network.emit(a)
        model.pauseSyncForBackground()
        let savedStatus = model.status
        network.finish(a, fail: true)
        await old.value
        expect(model.error.isEmpty && model.status == savedStatus, "background-invalidated errors must be ignored")
        let resumed = Task { await model.resumeSyncIfNeeded() }
        await network.waitForRequest(a, count: 2)
        let request = network.requests[a.id]![1]
        expect(request.stages == ["live"] && request.cachedItems.first?.name == "A", "resume must retain completed stages")
        network.finish(a, index: 1)
        await resumed.value
        expect(!model.loading && model.progress == 1, "background resume must complete")
        done("background resume retains the correct checkpoint")
    }

    @MainActor static func portalCredentials() async {
        let (model, a, _) = setup()
        model.playlists = [a]
        let old = await start(model, a)
        await network.emit(a)
        let oldCache = CatalogCacheStore.load(for: a.id)!
        UserDefaults.standard.set(oldCache, forKey: "catalogCheckpoint")
        UserDefaults.standard.set(oldCache, forKey: "catalogCheckpoint.\(a.id.uuidString)")
        var remote = a
        remote.id = UUID()
        remote.password = "updated"
        PortalClient.shared.remote = [remote]
        await model.syncPortalPlaylists()
        expect(model.selected?.password == "updated", "portal credentials must refresh the selected value-type copy")
        expect(model.playlists.count == 1 && model.selected?.id == a.id, "portal update must retain the local playlist ID without duplication")
        expect(!model.loading && model.items.isEmpty, "credential changes must invalidate in-flight catalog state")
        expect(CatalogCacheStore.load(for: a.id) == nil && UserDefaults.standard.data(forKey: "catalogCheckpoint") == nil &&
               UserDefaults.standard.data(forKey: "catalogCheckpoint.\(a.id.uuidString)") == nil,
               "credential changes must discard disk and legacy checkpoints")
        await network.emit(a)
        network.finish(a)
        await old.value
        expect(model.items.isEmpty, "old credentials cannot repopulate the updated playlist")
        let fresh = await start(model, a, count: 2)
        expect(network.requests[a.id]![1].provider.password == "updated", "the next catalog request must use updated credentials")
        network.finish(a, index: 1, label: "updated-A")
        await fresh.value
        let restored = AppModel()
        expect(restored.selected?.password == "updated" && restored.items.first?.name == "updated-A", "restart must restore the updated selection and its own checkpoint")
        done("portal credentials invalidate stale loads/caches and survive restart")
    }

    @MainActor static func portalMetadata() async {
        let (model, a, _) = setup()
        model.setLiveFormat("m3u8")
        let load = await start(model, a)
        network.finish(a)
        await load.value
        let cache = CatalogCacheStore.load(for: a.id)
        var remote = a
        remote.id = UUID()
        remote.name = "Renamed A"
        PortalClient.shared.remote = [remote]
        await model.syncPortalPlaylists()
        expect(model.selected?.name == "Renamed A" && model.selected?.id == a.id, "metadata must refresh without changing local identity")
        expect(model.items.first?.name == "A" && CatalogCacheStore.load(for: a.id) == cache && model.progress == 1,
               "metadata-only edits must not discard a valid catalog")
        expect(model.selected?.liveFormat == "m3u8" && model.playlists.first(where: { $0.id == a.id })?.liveFormat == "m3u8",
               "portal defaults must not reset the user's local playback-format preference")
        done("metadata-only portal edits preserve the catalog and local format")
    }

    @MainActor static func portalOutage() async {
        let (model, a, _) = setup()
        let before = model.playlists
        PortalClient.shared.fail = true
        await model.syncPortalPlaylists()
        expect(model.selected == a && model.playlists == before && model.error.isEmpty,
               "portal outages must preserve usable local playlists")
        PortalClient.shared.fail = false
        PortalClient.shared.remote = []
        await model.syncPortalPlaylists()
        expect(model.selected == a && model.playlists == before, "empty portal responses must preserve local playlists")
        done("portal outages and empty responses preserve local playlists")
    }

    @MainActor static func perPlaylistCache() async {
        let (model, a, b) = setup()
        let first = await start(model, a)
        network.finish(a)
        await first.value
        model.choose(b)
        let second = await start(model, b)
        network.finish(b)
        await second.value
        model.choose(a)
        expect(model.items.first?.name == "A" && model.progress == 1, "switching back must restore A's checkpoint")
        model.choose(b)
        expect(model.items.first?.name == "B" && model.progress == 1, "switching back must restore B's checkpoint")
        done("completed caches stay isolated across repeated switches")
    }

    @MainActor static func main() async {
        defer { UserDefaults.standard.removePersistentDomain(forName: UserDefaults.suiteName) }
        if CommandLine.arguments.contains("--portal-only") {
            await portalCredentials()
        } else {
            await switchBeforeReply()
            await overlappingRequests(failure: false)
            await overlappingRequests(failure: true)
            await addDuringLoad()
            await deleteDuringLoad(last: false)
            await deleteDuringLoad(last: true)
            await unchangedSelection()
            await backgroundResume()
            await portalCredentials()
            await portalMetadata()
            await portalOutage()
            await perPlaylistCache()
        }
        print("RESULT: \(passed) scenarios passed. No device, UI, or real-provider playback tests were performed.")
    }
}
