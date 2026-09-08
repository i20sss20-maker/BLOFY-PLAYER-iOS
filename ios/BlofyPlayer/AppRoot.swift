import SwiftUI

struct AppRoot: View {
    @EnvironmentObject var model: AppModel
    @State private var bootstrapping = true

    private var shouldShowProgress: Bool {
        guard model.activationAllowsUse, model.selected != nil else { return false }
        if model.loading { return true }
        if model.items.isEmpty && model.progress < 1 { return true }
        return model.progress > 0 && model.progress < 1
    }

    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()

            Group {
                if bootstrapping {
                    EntrySplashView()
                } else if !model.activationAllowsUse {
                    ActivationView()
                        .transition(.opacity)
                } else if shouldShowProgress {
                    SyncProgressView()
                        .transition(.opacity)
                } else {
                    SimpleRootView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: model.activationAllowsUse)
            .animation(.easeInOut(duration: 0.22), value: shouldShowProgress)
        }
        .tint(BlofyTheme.purpleBright)
        .preferredColorScheme(.dark)
        .task {
            await model.refreshActivation()
            bootstrapping = false
            guard model.activationAllowsUse else { return }
            await model.syncPortalPlaylists()
            if model.selected != nil {
                await model.loadCatalog()
            }
        }
    }
}

private struct EntrySplashView: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            BlofyBrandMark()
            ProgressView()
                .tint(BlofyTheme.purpleBright)
                .scaleEffect(1.1)
            Text("BLOFY PLAYER")
                .font(.caption.bold())
                .tracking(2)
                .foregroundStyle(BlofyTheme.textMuted)
            Spacer()
        }
        .padding(24)
    }
}
