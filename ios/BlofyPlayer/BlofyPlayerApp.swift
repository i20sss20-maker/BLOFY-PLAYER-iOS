import SwiftUI

@main
struct BlofyPlayerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environmentObject(model)
        }
    }
}
