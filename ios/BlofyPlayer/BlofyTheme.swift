import SwiftUI

enum BlofyTheme {
    static let background = Color(red: 10/255, green: 8/255, blue: 16/255)
    static let backgroundRaised = Color(red: 17/255, green: 13/255, blue: 25/255)
    static let surface = Color(red: 25/255, green: 20/255, blue: 34/255)
    static let surfaceRaised = Color(red: 32/255, green: 25/255, blue: 43/255)
    static let surfaceFocused = Color(red: 75/255, green: 42/255, blue: 112/255)
    static let purple = Color(red: 130/255, green: 69/255, blue: 218/255)
    static let purpleBright = Color(red: 174/255, green: 105/255, blue: 255/255)
    static let purpleDeep = Color(red: 67/255, green: 35/255, blue: 101/255)
    static let purpleSoft = Color(red: 205/255, green: 177/255, blue: 236/255)
    static let lavender = Color(red: 222/255, green: 205/255, blue: 239/255)
    static let mint = Color(red: 82/255, green: 216/255, blue: 181/255)
    static let error = Color(red: 255/255, green: 112/255, blue: 135/255)
    static let textPrimary = Color(red: 249/255, green: 247/255, blue: 252/255)
    static let textSecondary = Color(red: 218/255, green: 212/255, blue: 226/255)
    static let textMuted = Color(red: 157/255, green: 149/255, blue: 169/255)
    static let divider = Color(red: 53/255, green: 44/255, blue: 64/255)

    static let officialLogoURL = URL(string: "https://raw.githubusercontent.com/i20sss20-maker/BLOFY-PLAYER-2.0/rc07-commercial-stability/app/src/main/res/drawable-nodpi/blofy_logo.png")!

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [background, Color(red: 18/255, green: 11/255, blue: 28/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 86/255, green: 49/255, blue: 124/255), Color(red: 36/255, green: 23/255, blue: 47/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [purpleBright, Color(red: 117/255, green: 64/255, blue: 199/255)], startPoint: .leading, endPoint: .trailing)
    }
}

struct BlofyPanel: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(colors: [BlofyTheme.surface.opacity(0.96), BlofyTheme.backgroundRaised.opacity(0.98)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(BlofyTheme.divider, lineWidth: 1))
    }
}

extension View {
    func blofyPanel(radius: CGFloat = 20) -> some View { modifier(BlofyPanel(radius: radius)) }
}

struct BlofyBrandMark: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            AsyncImage(url: BlofyTheme.officialLogoURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous)
                            .fill(BlofyTheme.primaryGradient)
                        Image(systemName: "play.fill")
                            .font(.system(size: compact ? 13 : 18, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: compact ? 36 : 54, height: compact ? 36 : 54)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 9 : 13, style: .continuous))

            if !compact {
                Text("BLOFY PLAYER")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(BlofyTheme.textPrimary)
            }
        }
    }
}
