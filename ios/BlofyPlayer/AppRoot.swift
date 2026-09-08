import SwiftUI

struct AppRoot: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("blofyThemeStyle") private var themeStyle = "signature"
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
                    EntrySplashView().transition(.opacity)
                } else if !sessionEntered || !model.activationAllowsUse {
                    ActivationView {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) { sessionEntered = true }
                    }
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.985)), removal: .opacity.combined(with: .move(edge: .leading))))
                } else if shouldShowProgress {
                    PremiumSyncProgressView().transition(.opacity.combined(with: .scale(scale: 0.992)))
                } else {
                    SimpleRootView {
                        model.pauseSyncForBackground()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { sessionEntered = false }
                    }
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                }
            }
            .id(themeStyle)
            .animation(.easeInOut(duration: 0.24), value: sessionEntered)
            .animation(.easeInOut(duration: 0.24), value: model.activationAllowsUse)
            .animation(.easeInOut(duration: 0.24), value: shouldShowProgress)
        }
        .tint(BlofyTheme.purpleBright)
        .preferredColorScheme(.dark)
        .task {
            await model.refreshActivation()
            withAnimation(.easeOut(duration: 0.28)) { bootstrapping = false }
        }
    }
}

private struct EntrySplashView: View {
    @State private var glow = false
    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()
            Circle()
                .fill(BlofyTheme.purple.opacity(glow ? 0.2 : 0.1))
                .frame(width: glow ? 330 : 250, height: glow ? 330 : 250)
                .blur(radius: 60)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glow)
            VStack(spacing: 22) {
                Spacer()
                BlofyLogoGlyph(size: 104)
                VStack(spacing: 7) {
                    Text("BLOFY PLAYER").font(.system(size: 23, weight: .black, design: .rounded)).tracking(1.5).foregroundStyle(BlofyTheme.textPrimary)
                    Text("كل ترفيهك في مكان واحد").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                }
                Spacer()
                VStack(spacing: 11) {
                    ProgressView().tint(BlofyTheme.purpleBright)
                    Text("جاري تجهيز BLOFY").font(.caption2.bold()).foregroundStyle(BlofyTheme.textMuted)
                }.padding(.bottom, 22)
            }.padding(28)
        }
        .onAppear { glow = true }
    }
}
