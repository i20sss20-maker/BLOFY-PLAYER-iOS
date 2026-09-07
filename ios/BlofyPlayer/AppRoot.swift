import SwiftUI

struct AppRoot: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.activationAllowsUse {
                SimpleRootView()
            } else {
                ZStack {
                    BlofyTheme.backgroundGradient.ignoresSafeArea()
                    ActivationView()
                }
            }
        }
        .tint(BlofyTheme.purpleBright)
        .preferredColorScheme(.dark)
        .task {
            await model.refreshActivation()
            if model.activationAllowsUse {
                await model.syncPortalPlaylists()
                await model.loadCatalog()
            }
        }
    }
}
