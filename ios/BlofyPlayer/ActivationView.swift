import SwiftUI
import CoreImage.CIFilterBuiltins

struct ActivationView: View {
    @EnvironmentObject var model: AppModel
    @State private var checking = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("BLOFY PLAYER").font(.system(size: 38, weight: .black))
            Text("تفعيل الجهاز").font(.title2.bold()).foregroundStyle(.purple)

            if let image = qrImage {
                Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 210, height: 210)
                    .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 18))
            }

            VStack(spacing: 8) {
                Text(model.deviceID).font(.system(.title3, design: .monospaced).bold())
                Text(model.activationCode).font(.system(size: 34, weight: .black, design: .monospaced)).foregroundStyle(.purple)
            }

            Text(statusText).foregroundStyle(.secondary)
            Button { Task { await check() } } label: {
                if checking { ProgressView().frame(minWidth: 150) } else { Label("تحقق من التفعيل", systemImage: "arrow.clockwise") }
            }.buttonStyle(.borderedProminent).tint(.purple).disabled(checking)

            if let url = PortalClient.activationPortalURL(deviceID: model.deviceID, code: model.activationCode) {
                Link("فتح موقع إدارة القوائم", destination: url).buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding()
        .foregroundStyle(.white)
        .task { if model.activationStatus.isEmpty { await check() } }
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
