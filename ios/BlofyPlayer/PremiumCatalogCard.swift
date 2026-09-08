import SwiftUI

struct PremiumCatalogCard: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem

    private var progress: Double {
        guard let entry = model.resume[item.id], entry.duration > 0 else { return 0 }
        return min(max(entry.seconds / entry.duration, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Poster(url: item.poster)
                    .aspectRatio(0.68, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.52)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 5) {
                    if model.favorites.contains(item.id) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(BlofyTheme.purpleSoft)
                    }
                    if model.showRatings && !item.rating.isEmpty {
                        Label(item.rating, systemImage: "star.fill")
                            .foregroundStyle(.white)
                    }
                }
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(.black.opacity(0.62), in: Capsule())
                .padding(7)

                if progress > 0 {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.black.opacity(0.64))
                                Capsule()
                                    .fill(BlofyTheme.purpleBright)
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                        .frame(height: 4)
                        .padding(8)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.06)))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 6)

            Text(item.name)
                .font(.caption.bold())
                .foregroundStyle(BlofyTheme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 5) {
                Image(systemName: item.kind.icon)
                    .font(.system(size: 9))
                Text(item.kind == .movie ? "فيلم" : "مسلسل")
                    .font(.caption2.bold())
                if progress > 0 {
                    Text("· \(Int(progress * 100))٪")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(BlofyTheme.mint)
                }
            }
            .foregroundStyle(BlofyTheme.textMuted)
        }
    }
}
