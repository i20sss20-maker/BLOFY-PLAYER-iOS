import SwiftUI

struct PremiumSyncProgressView: View {
    @EnvironmentObject var model: AppModel

    private var percent: Int {
        max(0, min(100, Int((model.progress * 100).rounded())))
    }

    private var currentStage: String {
        if model.progress < 0.35 { return "البث المباشر" }
        if model.progress < 0.68 { return "الأفلام" }
        if model.progress < 0.94 { return "المسلسلات" }
        return "اللمسات الأخيرة"
    }

    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()

            Circle()
                .fill(BlofyTheme.purple.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 85)
                .offset(x: 130, y: -260)

            VStack(spacing: 28) {
                Spacer(minLength: 28)

                BlofyBrandMark()

                VStack(spacing: 6) {
                    Text("جاري تجهيز السيرفر")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(BlofyTheme.textPrimary)
                    Text(model.selected?.name ?? "BLOFY Server")
                        .font(.subheadline.bold())
                        .foregroundStyle(BlofyTheme.purpleSoft)
                        .lineLimit(1)
                }

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(BlofyTheme.surfaceRaised, lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: max(0.01, model.progress))
                            .stroke(BlofyTheme.primaryGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.25), value: model.progress)

                        VStack(spacing: 3) {
                            Text("\(percent)٪")
                                .font(.system(size: 46, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(BlofyTheme.textPrimary)
                            Text(currentStage)
                                .font(.caption.bold())
                                .foregroundStyle(BlofyTheme.textMuted)
                        }
                    }
                    .frame(width: 176, height: 176)
                    .shadow(color: BlofyTheme.purple.opacity(0.18), radius: 24)

                    ProgressView(value: model.progress)
                        .tint(BlofyTheme.purpleBright)
                        .scaleEffect(x: 1, y: 1.25)
                        .animation(.easeOut(duration: 0.25), value: model.progress)

                    Text(model.status.isEmpty ? "الاتصال بالسيرفر" : model.status)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BlofyTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(22)
                .background(BlofyTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(BlofyTheme.purpleSoft.opacity(0.18)))
                .shadow(color: .black.opacity(0.24), radius: 24, y: 14)

                HStack(spacing: 9) {
                    LoadingStage(title: "البث", icon: "tv.fill", done: model.progress >= 0.35)
                    LoadingStage(title: "الأفلام", icon: "film.fill", done: model.progress >= 0.68)
                    LoadingStage(title: "المسلسلات", icon: "play.rectangle.on.rectangle.fill", done: model.progress >= 0.94)
                }

                if !model.error.isEmpty {
                    Label(model.error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(BlofyTheme.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                HStack(spacing: 7) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text("نحفظ التقدم تلقائيًا ونكمل من نفس المرحلة إذا خرجت من التطبيق.")
                }
                .font(.caption2)
                .foregroundStyle(BlofyTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 22)
        }
    }
}

private struct LoadingStage: View {
    let title: String
    let icon: String
    let done: Bool

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(done ? BlofyTheme.mint.opacity(0.14) : BlofyTheme.surfaceRaised)
                    .frame(width: 42, height: 42)
                Image(systemName: done ? "checkmark" : icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(done ? BlofyTheme.mint : BlofyTheme.purpleSoft)
            }
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(done ? BlofyTheme.textPrimary : BlofyTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}
