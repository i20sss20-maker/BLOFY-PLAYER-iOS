import SwiftUI
import CoreImage.CIFilterBuiltins

struct ActivationView: View {
    @EnvironmentObject var model: AppModel
    @State private var checking = false
    @State private var showAdd = false
    let onSuccess: () -> Void

    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()

            Circle()
                .fill(BlofyTheme.purple.opacity(0.20))
                .frame(width: 360, height: 360)
                .blur(radius: 95)
                .offset(x: 150, y: -290)

            Circle()
                .fill(BlofyTheme.purpleDeep.opacity(0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: -170, y: 360)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 18) {
                    hero
                    accountCard
                    playlistsCard
                    accessCard
                    securityNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
        }
        .sheet(isPresented: $showAdd) { AddPlaylistView() }
    }

    private var hero: some View {
        VStack(spacing: 13) {
            BlofyLogoGlyph(size: 84)
            VStack(spacing: 5) {
                Text("BLOFY PLAYER")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(BlofyTheme.textPrimary)
                Text("كل ترفيهك وقوائمك في مكان واحد")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BlofyTheme.textSecondary)
                Text("اختر قائمتك ثم سجّل الدخول. بياناتك تبقى محفوظة على الجهاز.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BlofyTheme.textMuted)
            }
        }
        .padding(.vertical, 8)
    }

    private var accountCard: some View {
        VStack(spacing: 15) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("حساب BLOFY")
                        .font(.headline.bold())
                        .foregroundStyle(BlofyTheme.textPrimary)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(BlofyTheme.textMuted)
                }
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(statusBadge)
                        .font(.caption2.bold())
                        .foregroundStyle(BlofyTheme.textSecondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(BlofyTheme.surfaceRaised, in: Capsule())
            }

            HStack(spacing: 10) {
                LoginValue(title: "رقم الجهاز", value: model.deviceID, strong: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(BlofyTheme.divider).frame(width: 1, height: 42)
                LoginValue(title: "رمز الدخول", value: model.activationCode, strong: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { Task { await enter() } } label: {
                HStack(spacing: 10) {
                    if checking { ProgressView().tint(.white) }
                    else { Image(systemName: "rectangle.portrait.and.arrow.right.fill") }
                    Text(checking ? "جاري تسجيل الدخول…" : "تسجيل الدخول")
                    Spacer()
                    if !checking { Image(systemName: "arrow.left").font(.caption.bold()) }
                }
                .font(.headline.bold())
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity).frame(height: 55)
                .background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .disabled(checking)
            .opacity(checking ? 0.75 : 1)

            if !model.error.isEmpty {
                Label(model.error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(BlofyTheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(17)
        .blofyPanel(radius: 24)
    }

    private var playlistsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("قوائمي")
                        .font(.headline.bold())
                        .foregroundStyle(BlofyTheme.textPrimary)
                    Text(model.playlists.isEmpty ? "أضف قائمة للبدء" : "اختر السيرفر اللي تبي تدخل عليه")
                        .font(.caption2)
                        .foregroundStyle(BlofyTheme.textMuted)
                }
                Spacer()
                Button { showAdd = true } label: {
                    Label("إضافة", systemImage: "plus")
                        .font(.caption.bold())
                        .padding(.horizontal, 11).padding(.vertical, 8)
                        .background(BlofyTheme.surfaceRaised, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(BlofyTheme.purpleSoft)
            }

            if model.playlists.isEmpty {
                Button { showAdd = true } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 13).fill(BlofyTheme.purple.opacity(0.13)).frame(width: 48, height: 48)
                            Image(systemName: "plus.rectangle.on.folder.fill").foregroundStyle(BlofyTheme.purpleBright)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("إضافة أول قائمة")
                                .font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                            Text("Xtream Codes أو M3U")
                                .font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.left").font(.caption.bold()).foregroundStyle(BlofyTheme.textMuted)
                    }
                    .padding(12)
                    .background(BlofyTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.playlists.prefix(4)) { playlist in
                        Button {
                            model.choose(playlist)
                        } label: {
                            HStack(spacing: 11) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(model.selected?.id == playlist.id ? BlofyTheme.purple.opacity(0.22) : BlofyTheme.surfaceRaised)
                                        .frame(width: 45, height: 45)
                                    Image(systemName: playlist.type == "m3u" ? "list.bullet.rectangle.fill" : "server.rack")
                                        .foregroundStyle(model.selected?.id == playlist.id ? BlofyTheme.purpleBright : BlofyTheme.textSecondary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(playlist.name)
                                        .font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(1)
                                    Text(model.selected?.id == playlist.id ? "جاهز للدخول" : "اضغط للاختيار")
                                        .font(.caption2).foregroundStyle(model.selected?.id == playlist.id ? BlofyTheme.mint : BlofyTheme.textMuted)
                                }
                                Spacer()
                                if model.selected?.id == playlist.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(BlofyTheme.mint)
                                } else {
                                    Image(systemName: "circle").foregroundStyle(BlofyTheme.divider)
                                }
                            }
                            .padding(11)
                            .background(model.selected?.id == playlist.id ? BlofyTheme.purple.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(model.selected?.id == playlist.id ? BlofyTheme.purple.opacity(0.32) : BlofyTheme.divider))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(17)
        .blofyPanel(radius: 24)
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("إدارة الجهاز")
                        .font(.headline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                    Text("امسح الباركود من جهاز آخر أو افتح صفحة الإدارة")
                        .font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                }
                Spacer()
            }

            HStack(spacing: 14) {
                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable().scaledToFit()
                        .frame(width: 94, height: 94)
                        .padding(8)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }

                VStack(spacing: 9) {
                    if let url = PortalClient.activationPortalURL(deviceID: model.deviceID, code: model.activationCode) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "safari.fill")
                                Text("فتح بوابة BLOFY")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 13).frame(height: 46)
                            .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .foregroundStyle(BlofyTheme.textPrimary)
                    }
                    Button { showAdd = true } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("إضافة قائمة يدويًا")
                            Spacer()
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 13).frame(height: 46)
                        .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BlofyTheme.purpleSoft)
                }
            }
        }
        .padding(17)
        .blofyPanel(radius: 24)
    }

    private var securityNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill").foregroundStyle(BlofyTheme.mint)
            Text("تسجيل الخروج يرجعك لهذه الصفحة فقط، ولا يحذف القوائم أو المفضلة أو تقدم المشاهدة.")
        }
        .font(.caption2)
        .foregroundStyle(BlofyTheme.textMuted)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
    }

    private var statusColor: Color {
        switch model.activationStatus.lowercased() {
        case "active", "trial": return BlofyTheme.mint
        case "expired", "blocked": return BlofyTheme.error
        default: return BlofyTheme.textMuted
        }
    }

    private var statusBadge: String {
        switch model.activationStatus.lowercased() {
        case "active": return "مفعّل"
        case "trial": return "تجريبي"
        case "expired": return "منتهي"
        case "blocked": return "موقوف"
        case "offline": return "غير متصل"
        default: return "جاهز"
        }
    }

    private var statusText: String {
        switch model.activationStatus.lowercased() {
        case "active": return "الجهاز مفعّل وجاهز"
        case "trial": return "الفترة التجريبية فعالة"
        case "expired": return "انتهت مدة التفعيل"
        case "blocked": return "الجهاز موقوف"
        case "offline": return "تعذر التحقق من الخدمة"
        default: return "سجّل الدخول للوصول إلى محتواك"
        }
    }

    private func enter() async {
        guard !checking else { return }
        checking = true
        model.error = ""
        await model.refreshActivation()

        guard model.activationAllowsUse else {
            checking = false
            return
        }

        await model.syncPortalPlaylists()
        onSuccess()
        if model.selected != nil { await model.loadCatalog() }
        checking = false
    }

    private var qrImage: UIImage? {
        guard let url = PortalClient.activationPortalURL(deviceID: model.deviceID, code: model.activationCode) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        let context = CIContext()
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

private struct LoginValue: View {
    let title: String
    let value: String
    let strong: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(BlofyTheme.textMuted)
            Text(value)
                .font(.system(size: strong ? 22 : 14, weight: .black, design: .monospaced))
                .foregroundStyle(strong ? BlofyTheme.purpleBright : BlofyTheme.textPrimary)
                .minimumScaleFactor(0.56)
                .lineLimit(1)
        }
    }
}
