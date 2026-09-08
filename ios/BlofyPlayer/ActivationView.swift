import SwiftUI
import CoreImage.CIFilterBuiltins

struct ActivationView: View {
    @EnvironmentObject var model: AppModel
    @State private var checking = false
    let onSuccess: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer(minLength: 28)

                VStack(spacing: 12) {
                    BlofyBrandMark()
                    Text("أهلًا بك في BLOFY PLAYER")
                        .font(.system(size: 29, weight: .black))
                        .foregroundStyle(BlofyTheme.textPrimary)
                    Text("ادخل لجهازك ثم انتقل للسيرفر والقوائم المحفوظة")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BlofyTheme.textMuted)
                }

                VStack(spacing: 18) {
                    HStack(spacing: 14) {
                        if let image = qrImage {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 116, height: 116)
                                .padding(10)
                                .background(.white, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            LoginValue(title: "رقم الجهاز", value: model.deviceID, strong: false)
                            LoginValue(title: "رمز الدخول", value: model.activationCode, strong: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider().overlay(BlofyTheme.divider)

                    HStack(spacing: 9) {
                        Circle().fill(statusColor).frame(width: 9, height: 9)
                        Text(statusText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BlofyTheme.textSecondary)
                        Spacer()
                    }

                    Button { Task { await enter() } } label: {
                        HStack(spacing: 10) {
                            if checking { ProgressView().tint(.white) }
                            else { Image(systemName: "arrow.right.circle.fill") }
                            Text(checking ? "جاري الدخول…" : "دخول إلى BLOFY")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .disabled(checking)

                    if let url = PortalClient.activationPortalURL(deviceID: model.deviceID, code: model.activationCode) {
                        Link(destination: url) {
                            Label("إدارة القوائم من المتصفح", systemImage: "safari")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(BlofyTheme.divider))
                        }
                        .foregroundStyle(BlofyTheme.purpleSoft)
                    }
                }
                .padding(18)
                .background(BlofyTheme.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(BlofyTheme.purpleSoft.opacity(0.22)))
                .shadow(color: BlofyTheme.purple.opacity(0.12), radius: 24, y: 12)

                Text("تسجيل الخروج لاحقًا يرجعك لهذه الصفحة بدون حذف السيرفرات أو المفضلة.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BlofyTheme.textMuted)
                    .padding(.horizontal, 12)

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 20)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
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
        case "active": return "الجهاز مفعّل وجاهز"
        case "trial": return "الفترة التجريبية فعالة"
        case "expired": return "انتهت مدة التفعيل"
        case "blocked": return "الجهاز موقوف"
        case "offline": return "تعذر التحقق من الخدمة"
        default: return "اضغط دخول للتحقق من الجهاز"
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(BlofyTheme.textMuted)
            Text(value)
                .font(.system(size: strong ? 24 : 15, weight: .black, design: .monospaced))
                .foregroundStyle(strong ? BlofyTheme.purpleBright : BlofyTheme.textPrimary)
                .minimumScaleFactor(0.66)
                .lineLimit(1)
        }
    }
}
