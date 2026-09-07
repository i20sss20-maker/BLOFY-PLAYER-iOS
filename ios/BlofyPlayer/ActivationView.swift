import SwiftUI
import CoreImage.CIFilterBuiltins

struct ActivationView: View {
    @EnvironmentObject var model: AppModel
    @State private var checking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 36)
                BlofyBrandMark()

                VStack(spacing: 7) {
                    Text("تفعيل BLOFY PLAYER")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(BlofyTheme.textPrimary)
                    Text("امسح الرمز أو استخدم رقم الجهاز والرمز في بوابة BLOFY")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BlofyTheme.textMuted)
                }

                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none).resizable().scaledToFit()
                        .frame(width: 205, height: 205)
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(BlofyTheme.purpleSoft.opacity(0.5), lineWidth: 2))
                        .shadow(color: BlofyTheme.purple.opacity(0.22), radius: 22)
                }

                VStack(spacing: 14) {
                    ActivationValue(title: "رقم الجهاز", value: model.deviceID, prominent: false)
                    ActivationValue(title: "رمز التفعيل", value: model.activationCode, prominent: true)
                }
                .padding(18)
                .blofyPanel(radius: 22)

                HStack(spacing: 8) {
                    Circle().fill(statusColor).frame(width: 9, height: 9)
                    Text(statusText).font(.subheadline.weight(.semibold)).foregroundStyle(BlofyTheme.textSecondary)
                }

                Button { Task { await check() } } label: {
                    HStack {
                        if checking { ProgressView().tint(.white) }
                        else { Image(systemName: "arrow.clockwise") }
                        Text(checking ? "جاري التحقق" : "تحقق من التفعيل")
                    }
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain).foregroundStyle(.white).disabled(checking)

                if let url = PortalClient.activationPortalURL(deviceID: model.deviceID, code: model.activationCode) {
                    Link(destination: url) {
                        Label("فتح بوابة إدارة القوائم", systemImage: "safari")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(BlofyTheme.divider))
                    }
                    .foregroundStyle(BlofyTheme.purpleSoft)
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
        .task { if model.activationStatus.isEmpty { await check() } }
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
        case "active": return "الجهاز مفعّل"
        case "trial": return "الفترة التجريبية فعالة"
        case "expired": return "انتهت مدة التفعيل"
        case "blocked": return "الجهاز موقوف"
        case "offline": return "تعذر التحقق من الخدمة"
        default: return "جاري التحقق من حالة الجهاز"
        }
    }

    private func check() async {
        checking = true
        await model.refreshActivation()
        if model.activationAllowsUse { await model.syncPortalPlaylists(); await model.loadCatalog() }
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

private struct ActivationValue: View {
    let title: String
    let value: String
    let prominent: Bool
    var body: some View {
        VStack(spacing: 5) {
            Text(title).font(.caption).foregroundStyle(BlofyTheme.textMuted)
            Text(value)
                .font(.system(size: prominent ? 31 : 17, weight: .black, design: .monospaced))
                .foregroundStyle(prominent ? BlofyTheme.purpleBright : BlofyTheme.textPrimary)
                .minimumScaleFactor(0.7).lineLimit(1)
        }.frame(maxWidth: .infinity)
    }
}
