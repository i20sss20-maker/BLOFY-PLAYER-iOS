import Foundation

extension AppModel {
    func refreshActivation() async {
        do {
            let result = try await PortalClient.shared.checkActivation(deviceID: deviceID, code: activationCode)
            activationStatus = result.status
        } catch {
            activationStatus = "offline"
            self.error = error.localizedDescription
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
                    merged[match] = updated
                } else {
                    merged.append(provider)
                }
            }
            playlists = merged
            if selected == nil { selected = merged.first }
            savePlaylists()
        } catch {
            self.error = error.localizedDescription
        }
    }

    var activationAllowsUse: Bool {
        ["trial", "active"].contains(activationStatus.lowercased())
    }
}
