import SwiftUI

enum BlofyTheme {
    static let background = Color(red: 8/255, green: 6/255, blue: 13/255)
    static let backgroundRaised = Color(red: 15/255, green: 11/255, blue: 23/255)
    static let surface = Color(red: 23/255, green: 18/255, blue: 32/255)
    static let surfaceRaised = Color(red: 31/255, green: 24/255, blue: 42/255)
    static let surfaceFocused = Color(red: 77/255, green: 43/255, blue: 116/255)
    static let purple = Color(red: 132/255, green: 72/255, blue: 220/255)
    static let purpleBright = Color(red: 182/255, green: 112/255, blue: 255/255)
    static let purpleDeep = Color(red: 65/255, green: 33/255, blue: 101/255)
    static let purpleSoft = Color(red: 208/255, green: 181/255, blue: 239/255)
    static let lavender = Color(red: 226/255, green: 211/255, blue: 242/255)
    static let mint = Color(red: 87/255, green: 221/255, blue: 185/255)
    static let error = Color(red: 255/255, green: 112/255, blue: 135/255)
    static let textPrimary = Color(red: 250/255, green: 248/255, blue: 253/255)
    static let textSecondary = Color(red: 221/255, green: 215/255, blue: 230/255)
    static let textMuted = Color(red: 158/255, green: 150/255, blue: 171/255)
    static let divider = Color(red: 54/255, green: 44/255, blue: 66/255)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                background,
                Color(red: 16/255, green: 10/255, blue: 25/255),
                Color(red: 11/255, green: 8/255, blue: 18/255),
                background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 96/255, green: 52/255, blue: 142/255),
                Color(red: 47/255, green: 27/255, blue: 67/255),
                backgroundRaised
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [purpleBright, purple, Color(red: 111/255, green: 58/255, blue: 193/255)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var glassGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.065), purple.opacity(0.06), Color.white.opacity(0.015)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var subtleGlow: RadialGradient {
        RadialGradient(
            colors: [purple.opacity(0.16), .clear],
            center: .topLeading,
            startRadius: 6,
            endRadius: 260
        )
    }
}

struct BlofyPanel: ViewModifier {
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    LinearGradient(
                        colors: [BlofyTheme.surface.opacity(0.985), BlofyTheme.backgroundRaised.opacity(0.995)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    BlofyTheme.glassGradient
                    BlofyTheme.subtleGlow.opacity(0.34)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.105), BlofyTheme.purple.opacity(0.12), BlofyTheme.divider.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
            .shadow(color: BlofyTheme.purple.opacity(0.055), radius: 18, y: 3)
    }
}

extension View {
    func blofyPanel(radius: CGFloat = 20) -> some View { modifier(BlofyPanel(radius: radius)) }
}

struct BlofyBrandMark: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            Image("blofy_logo")
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 38 : 58, height: compact ? 38 : 58)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                        .stroke(Color.white.opacity(0.09))
                )
                .shadow(color: BlofyTheme.purple.opacity(compact ? 0.16 : 0.27), radius: compact ? 10 : 17, y: 6)

            if !compact {
                VStack(alignment: .leading, spacing: 1) {
                    Text("BLOFY PLAYER")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(BlofyTheme.textPrimary)
                    Text("PREMIUM PLAYER")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(1.9)
                        .foregroundStyle(BlofyTheme.purpleSoft.opacity(0.76))
                }
            }
        }
    }
}
