import SwiftUI

struct PremiumSyncProgressView: View {
    @EnvironmentObject var model: AppModel

    private var percent: Int {
        max(0, min(100, Int((model.progress * 100).rounded())))
    }

    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 34)

                BlofyBrandMark()

                VStack(spacing: 7) {
                    Text("جاري تجهيز السيرفر")
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(BlofyTheme.textPrimary)
                    Text(model.selected?.name ?? "BLOFY Server")
                        .font(.subheadline.bold())
                        .foregroundStyle(BlofyTheme.purpleSoft)
                        .lineLimit(1)
                }

                ZStack {
                    Circle()
                        .stroke(BlofyTheme.surfaceRaised, lineWidth: 13)
                    Circle()
                        .trim(from: 0, to: max(0.01, model.progress))
                        .stroke(BlofyTheme.primaryGradient, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.25), value: model.progress)

                    VStack(spacing: 2) {
                        Text("\(percent)٪")
                            .font(.system(size: 43, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(BlofyTheme.textPrimary)
                        Text("تحميل")
                            .font(.caption.bold())
                            .foregroundStyle(BlofyTheme.textMuted)
                    }
                }
                .frame(width: 172, height: 172)
                .shadow(color: BlofyTheme.purple.opacity(0.18), radius: 24)

                VStack(spacing: 13) {
                    Text(model.status.isEmpty ? "الاتصال بالسيرفر" : model.status)
                        .font(.headline)
                        .foregroundStyle(BlofyTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        LoadingStage(title: "البث", icon: "tv.fill", done: model.progress >= 0.35)
                        LoadingStage(title: "الأفلام", icon: "film.fill", done: model.progress >= 0.68)
                        LoadingStage(title: "المسلسلات", icon: "play.rectangle.on.rectangle.fill", done: model.progress >= 0.94)
                    }

                    if !model.error.isEmpty {
                        Label(model.error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(BlofyTheme.error)
                            .multilineTextAlignment(.center)
                            .padding(.top, 3)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(BlofyTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(BlofyTheme.divider))

                Text("نحفظ التقدم تلقائيًا. لو خرجت من التطبيق نكمل من آخر مرحلة محفوظة.")
                    .font(.caption)
                    .foregroundStyle(BlofyTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)

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
        VStack(spacing: 6) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .font(.headline)
                .foregroundStyle(done ? BlofyTheme.mint : BlofyTheme.purpleSoft)
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(done ? BlofyTheme.textPrimary : BlofyTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}
