import Foundation

extension AppModel {
    private var activationCacheStatusKey: String { "activation.lastValidStatus" }
    private var activationCacheDateKey: String { "activation.lastValidatedAt" }
    private var activationGraceInterval: TimeInterval { 24 * 60 * 60 }

    func refreshActivation() async {
        do {
            let result = try await PortalClient.shared.checkActivation(deviceID: deviceID, code: activationCode)
            let normalized = result.status.lowercased()
            activationStatus = result.status
            if ["trial", "active"].contains(normalized) {
                UserDefaults.standard.set(result.status, forKey: activationCacheStatusKey)
                UserDefaults.standard.set(Date(), forKey: activationCacheDateKey)
                if error.contains("التفعيل") || error.contains("الاتصال") { error = "" }
            } else {
                UserDefaults.standard.removeObject(forKey: activationCacheStatusKey)
                UserDefaults.standard.removeObject(forKey: activationCacheDateKey)
            }
        } catch {
            activationStatus = "offline"
            if !activationAllowsUse {
                self.error = "تعذر التحقق من التفعيل · تحقق من الاتصال وحاول مرة أخرى"
            }
        }
    }

    func syncPortalPlaylists() async {
        do {
            let remote = try await PortalClient.shared.portalPlaylists(deviceID: deviceID, code: activationCode)
            guard !remote.isEmpty else { return }
            var merged = playlists
            for provider in remote {
                let match = merged.firstIndex { existing in
                    existing.type == provider.type &&
                    existing.url.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == provider.url.trimmingCharacters(in: CharacterSet(charactersIn: "/")) &&
                    existing.username == provider.username
                }
                if let match {
                    let oldID = merged[match].id
                    var updated = provider
                    updated.id = oldID
                    // The portal has no playback-format setting; retain the user's local choice.
                    updated.liveFormat = merged[match].liveFormat
                    merged[match] = updated
                } else {
                    merged.append(provider)
                }
            }
            playlists = merged
            if let selectedID = selected?.id,
               let updated = merged.first(where: { $0.id == selectedID }) {
                updateSelectedPlaylist(updated)
            } else if selected == nil {
                selected = merged.first
            }
            savePlaylists()
        } catch {
            // Keep local playlists usable when the portal has a temporary outage.
            if playlists.isEmpty { self.error = error.localizedDescription }
        }
    }

    var activationAllowsUse: Bool {
        let normalized = activationStatus.lowercased()
        if ["trial", "active"].contains(normalized) { return true }
        guard normalized == "offline" || normalized.isEmpty else { return false }

        let defaults = UserDefaults.standard
        guard let cached = defaults.string(forKey: activationCacheStatusKey)?.lowercased(),
              ["trial", "active"].contains(cached),
              let validatedAt = defaults.object(forKey: activationCacheDateKey) as? Date else { return false }
        return Date().timeIntervalSince(validatedAt) <= activationGraceInterval
    }
}
