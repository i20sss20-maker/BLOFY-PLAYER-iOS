import SwiftUI

enum BlofyTheme {
    static var style: String { UserDefaults.standard.string(forKey: "blofyThemeStyle") ?? "signature" }

    static var background: Color {
        switch style {
        case "midnight": return Color(red: 5/255, green: 8/255, blue: 16/255)
        case "graphite": return Color(red: 11/255, green: 11/255, blue: 14/255)
        default: return Color(red: 10/255, green: 8/255, blue: 16/255)
        }
    }
    static var backgroundRaised: Color {
        switch style {
        case "midnight": return Color(red: 10/255, green: 16/255, blue: 29/255)
        case "graphite": return Color(red: 20/255, green: 20/255, blue: 24/255)
        default: return Color(red: 17/255, green: 13/255, blue: 25/255)
        }
    }
    static var surface: Color {
        switch style {
        case "midnight": return Color(red: 15/255, green: 24/255, blue: 40/255)
        case "graphite": return Color(red: 28/255, green: 28/255, blue: 33/255)
        default: return Color(red: 25/255, green: 20/255, blue: 34/255)
        }
    }
    static var surfaceRaised: Color {
        switch style {
        case "midnight": return Color(red: 21/255, green: 32/255, blue: 52/255)
        case "graphite": return Color(red: 36/255, green: 36/255, blue: 42/255)
        default: return Color(red: 32/255, green: 25/255, blue: 43/255)
        }
    }
    static var surfaceFocused: Color {
        switch style {
        case "midnight": return Color(red: 43/255, green: 63/255, blue: 105/255)
        case "graphite": return Color(red: 76/255, green: 67/255, blue: 96/255)
        default: return Color(red: 75/255, green: 42/255, blue: 112/255)
        }
    }
    static var purple: Color {
        switch style {
        case "midnight": return Color(red: 112/255, green: 94/255, blue: 238/255)
        case "graphite": return Color(red: 142/255, green: 108/255, blue: 201/255)
        default: return Color(red: 130/255, green: 69/255, blue: 218/255)
        }
    }
    static var purpleBright: Color {
        switch style {
        case "midnight": return Color(red: 146/255, green: 132/255, blue: 255/255)
        case "graphite": return Color(red: 180/255, green: 143/255, blue: 235/255)
        default: return Color(red: 174/255, green: 105/255, blue: 255/255)
        }
    }
    static var purpleDeep: Color {
        switch style {
        case "midnight": return Color(red: 36/255, green: 44/255, blue: 94/255)
        case "graphite": return Color(red: 58/255, green: 49/255, blue: 70/255)
        default: return Color(red: 67/255, green: 35/255, blue: 101/255)
        }
    }
    static var purpleSoft: Color {
        switch style {
        case "midnight": return Color(red: 190/255, green: 187/255, blue: 255/255)
        case "graphite": return Color(red: 215/255, green: 194/255, blue: 235/255)
        default: return Color(red: 205/255, green: 177/255, blue: 236/255)
        }
    }

    static let lavender = Color(red: 222/255, green: 205/255, blue: 239/255)
    static let mint = Color(red: 82/255, green: 216/255, blue: 181/255)
    static let error = Color(red: 255/255, green: 112/255, blue: 135/255)
    static let textPrimary = Color(red: 249/255, green: 247/255, blue: 252/255)
    static let textSecondary = Color(red: 218/255, green: 212/255, blue: 226/255)
    static let textMuted = Color(red: 157/255, green: 149/255, blue: 169/255)
    static var divider: Color {
        switch style {
        case "midnight": return Color(red: 39/255, green: 51/255, blue: 72/255)
        case "graphite": return Color(red: 57/255, green: 57/255, blue: 66/255)
        default: return Color(red: 53/255, green: 44/255, blue: 64/255)
        }
    }

    static var backgroundGradient: LinearGradient {
        let middle: Color
        switch style {
        case "midnight": middle = Color(red: 8/255, green: 17/255, blue: 34/255)
        case "graphite": middle = Color(red: 23/255, green: 21/255, blue: 28/255)
        default: middle = Color(red: 18/255, green: 11/255, blue: 28/255)
        }
        return LinearGradient(colors: [background, middle, background], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [purpleDeep.opacity(0.95), surfaceFocused.opacity(0.72), backgroundRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [purpleBright, purple], startPoint: .leading, endPoint: .trailing)
    }

    static var glassGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.055), purple.opacity(0.055), Color.white.opacity(0.018)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct BlofyPanel: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    LinearGradient(colors: [BlofyTheme.surface.opacity(0.97), BlofyTheme.backgroundRaised.opacity(0.99)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    BlofyTheme.glassGradient
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.08), BlofyTheme.divider.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }
}

extension View {
    func blofyPanel(radius: CGFloat = 20) -> some View { modifier(BlofyPanel(radius: radius)) }
}

struct BlofyLogoGlyph: View {
    var size: CGFloat = 58
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [BlofyTheme.purpleBright, BlofyTheme.purple, BlofyTheme.purpleDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .fill(Color.white.opacity(0.13))
                .frame(width: size * 0.72, height: size * 0.72)
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.36, weight: .black))
                .foregroundStyle(.white)
                .offset(x: size * 0.035)
        }
        .frame(width: size, height: size)
        .overlay(RoundedRectangle(cornerRadius: size * 0.24).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: BlofyTheme.purple.opacity(0.30), radius: size * 0.25, y: size * 0.10)
        .accessibilityLabel("BLOFY PLAYER")
    }
}

struct BlofyBrandMark: View {
    var compact = false
    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            BlofyLogoGlyph(size: compact ? 38 : 58)
            if !compact {
                VStack(alignment: .leading, spacing: 1) {
                    Text("BLOFY PLAYER")
                        .font(.system(size: 18, weight: .black, design: .rounded)).tracking(0.7).foregroundStyle(BlofyTheme.textPrimary)
                    Text("ENTERTAINMENT")
                        .font(.system(size: 7, weight: .bold, design: .rounded)).tracking(1.8).foregroundStyle(BlofyTheme.purpleSoft.opacity(0.72))
                }
            }
        }
    }
}