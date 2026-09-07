import SwiftUI

struct AppRoot: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.activationAllowsUse {
                RootView()
            } else {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.035, green: 0.025, blue: 0.06), Color(red: 0.08, green: 0.045, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                    ActivationView()
                }
            }
        }
        .task {
            await model.refreshActivation()
            if model.activationAllowsUse {
                await model.syncPortalPlaylists()
                await model.loadCatalog()
            }
        }
    }
}
