import SwiftUI

struct AppRoot: View {
    @EnvironmentObject var model: AppModel
    @State private var bootstrapping = true
    @State private var sessionEntered = false

    private var shouldShowProgress: Bool {
        guard sessionEntered, model.activationAllowsUse, model.selected != nil else { return false }
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
                } else if !sessionEntered || !model.activationAllowsUse {
                    ActivationView {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            sessionEntered = true
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else if shouldShowProgress {
                    PremiumSyncProgressView()
                        .transition(.opacity.combined(with: .scale(scale: 0.99)))
                } else {
                    SimpleRootView {
                        model.pauseSyncForBackground()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            sessionEntered = false
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.24), value: sessionEntered)
            .animation(.easeInOut(duration: 0.24), value: model.activationAllowsUse)
            .animation(.easeInOut(duration: 0.24), value: shouldShowProgress)
        }
        .tint(BlofyTheme.purpleBright)
        .preferredColorScheme(.dark)
        .task {
            await model.refreshActivation()
            bootstrapping = false
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
