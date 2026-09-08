import SwiftUI
import CoreImage.CIFilterBuiltins

struct ActivationView: View {
    @EnvironmentObject var model: AppModel
    @State private var checking = false
    let onSuccess: () -> Void

    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()

            Circle()
                .fill(BlofyTheme.purple.opacity(0.18))
                .frame(width: 330, height: 330)
                .blur(radius: 80)
                .offset(x: 135, y: -260)

            Circle()
                .fill(BlofyTheme.purpleDeep.opacity(0.24))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: -150, y: 300)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer(minLength: 34)

                    VStack(spacing: 14) {
                        BlofyBrandMark()
                        Text("مشاهدة أبسط. تجربة أقوى.")
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(BlofyTheme.textPrimary)
                        Text("اربط جهازك مرة واحدة، وبعدها ادخل لسيرفرك وقوائمك المحفوظة.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(BlofyTheme.textMuted)
                            .padding(.horizontal, 14)
                    }

                    VStack(spacing: 18) {
                        HStack(alignment: .center, spacing: 16) {
                            if let image = qrImage {
                                VStack(spacing: 7) {
                                    Image(uiImage: image)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 110, height: 110)
                                        .padding(9)
                                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    Text("امسح للدخول")
                                        .font(.caption2.bold())
                                        .foregroundStyle(BlofyTheme.textMuted)
                                }
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                LoginValue(title: "رقم الجهاز", value: model.deviceID, strong: false)
                                Divider().overlay(BlofyTheme.divider)
                                LoginValue(title: "رمز الدخول", value: model.activationCode, strong: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(spacing: 9) {
                            Circle().fill(statusColor).frame(width: 9, height: 9)
                            Text(statusText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BlofyTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(BlofyTheme.surfaceRaised, in: Capsule())

                        Button { Task { await enter() } } label: {
                            HStack(spacing: 10) {
                                if checking { ProgressView().tint(.white) }
                                else { Image(systemName: "arrow.right") }
                                Text(checking ? "جاري التحقق…" : "الدخول إلى السيرفر")
                            }
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .disabled(checking)
                        .opacity(checking ? 0.75 : 1)

                        if let url = PortalClient.activationPortalURL(deviceID: model.deviceID, code: model.activationCode) {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "safari")
                                    Text("إدارة القوائم من المتصفح")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.subheadline.bold())
                                .padding(.horizontal, 15)
                                .padding(.vertical, 13)
                                .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(BlofyTheme.divider))
                            }
                            .foregroundStyle(BlofyTheme.textSecondary)
                        }
                    }
                    .padding(19)
                    .background(
                        LinearGradient(
                            colors: [BlofyTheme.surface.opacity(0.97), BlofyTheme.backgroundRaised.opacity(0.98)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(BlofyTheme.purpleSoft.opacity(0.20)))
                    .shadow(color: .black.opacity(0.28), radius: 28, y: 18)

                    HStack(spacing: 7) {
                        Image(systemName: "lock.shield.fill")
                        Text("بيانات السيرفر والمفضلة تبقى محفوظة على جهازك عند تسجيل الخروج.")
                    }
                    .font(.caption2)
                    .foregroundStyle(BlofyTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var statusColor: Color {
        switch model.activationStatus.lowercased() {
        case "active", "trial": return BlofyTheme.mint
        case "expired", "blocked": return BlofyTheme.error
        default: return BlofyTheme.textMuted
        }
    }

    private var statusText: String {
        switch model.activationStatus.lowercased() {
        case "active": return "الجهاز مفعّل وجاهز للدخول"
        case "trial": return "الفترة التجريبية فعالة"
        case "expired": return "انتهت مدة التفعيل"
        case "blocked": return "الجهاز موقوف"
        case "offline": return "تعذر التحقق من الخدمة"
        default: return "جاهز للتحقق من الجهاز"
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

        if model.selected != nil {
            await model.loadCatalog()
        }
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
                .font(.system(size: strong ? 24 : 15, weight: .black, design: .monospaced))
                .foregroundStyle(strong ? BlofyTheme.purpleBright : BlofyTheme.textPrimary)
                .minimumScaleFactor(0.62)
                .lineLimit(1)
        }
    }
}
