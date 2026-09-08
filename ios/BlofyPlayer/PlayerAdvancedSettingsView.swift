import SwiftUI

struct PlayerAdvancedSettingsView: View {
    @AppStorage("preferredAudioLanguage") private var preferredAudioLanguage = "auto"
    @AppStorage("preferredSubtitleLanguage") private var preferredSubtitleLanguage = "auto"
    @AppStorage("autoEnableSubtitles") private var autoEnableSubtitles = false
    @AppStorage("subtitleScale") private var subtitleScale = 1.0
    @AppStorage("subtitleDelayMs") private var subtitleDelayMs = 0.0
    @AppStorage("defaultPlaybackRate") private var defaultPlaybackRate = 1.0
    @AppStorage("videoAspectMode") private var videoAspectMode = "fit"
    @AppStorage("showPlayerEngineBadge") private var showPlayerEngineBadge = false
    @AppStorage("rememberTrackSelection") private var rememberTrackSelection = true
    @AppStorage("lastAudioTrackName") private var lastAudioTrackName = ""
    @AppStorage("lastSubtitleTrackName") private var lastSubtitleTrackName = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack {
                    BlofyBrandMark(compact: true)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("تفضيلات المشاهدة").font(.title2.bold())
                        Text("الصوت · الترجمة · الصورة").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                    }
                }.padding(.horizontal, 16).padding(.top, 10)

                AdvancedCard(title: "الصوت", icon: "speaker.wave.3.fill") {
                    Text("اللغة المفضلة").font(.subheadline.bold())
                    Picker("لغة الصوت", selection: $preferredAudioLanguage) {
                        Text("تلقائي").tag("auto")
                        Text("العربية").tag("ar")
                        Text("English").tag("en")
                        Text("الأولى المتاحة").tag("first")
                    }.pickerStyle(.segmented)
                    if rememberTrackSelection && !lastAudioTrackName.isEmpty {
                        Text("آخر اختيار: \(lastAudioTrackName)").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                    }
                }

                AdvancedCard(title: "الترجمة", icon: "captions.bubble.fill") {
                    Toggle("تشغيل الترجمة تلقائيًا", isOn: $autoEnableSubtitles).tint(BlofyTheme.purpleBright)
                    Divider().overlay(BlofyTheme.divider)
                    Text("لغة الترجمة").font(.subheadline.bold())
                    Picker("لغة الترجمة", selection: $preferredSubtitleLanguage) {
                        Text("تلقائي").tag("auto")
                        Text("العربية").tag("ar")
                        Text("English").tag("en")
                        Text("الأولى المتاحة").tag("first")
                    }.pickerStyle(.segmented)
                    Divider().overlay(BlofyTheme.divider)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("حجم الترجمة"); Spacer(); Text("\(Int(subtitleScale * 100))٪").foregroundStyle(BlofyTheme.purpleSoft) }
                        Slider(value: $subtitleScale, in: 0.75...1.5, step: 0.05).tint(BlofyTheme.purpleBright)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("توقيت الترجمة"); Spacer(); Text(formatDelay(subtitleDelayMs)).foregroundStyle(BlofyTheme.purpleSoft) }
                        Slider(value: $subtitleDelayMs, in: -5000...5000, step: 250).tint(BlofyTheme.purpleBright)
                    }
                    if rememberTrackSelection && !lastSubtitleTrackName.isEmpty {
                        Text("آخر اختيار: \(lastSubtitleTrackName)").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                    }
                }

                AdvancedCard(title: "الصورة", icon: "rectangle.inset.filled") {
                    Text("طريقة عرض الفيديو").font(.subheadline.bold())
                    Picker("نسبة العرض", selection: $videoAspectMode) {
                        Text("احتواء").tag("fit")
                        Text("ملء").tag("fill")
                        Text("16:9").tag("16:9")
                    }.pickerStyle(.segmented)
                    Divider().overlay(BlofyTheme.divider)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("سرعة التشغيل الافتراضية"); Spacer(); Text(String(format: "%.2fx", defaultPlaybackRate)).foregroundStyle(BlofyTheme.purpleSoft) }
                        Slider(value: $defaultPlaybackRate, in: 0.5...2.0, step: 0.25).tint(BlofyTheme.purpleBright)
                    }
                    Toggle("تذكر آخر صوت وترجمة", isOn: $rememberTrackSelection).tint(BlofyTheme.purpleBright)
                }

                AdvancedCard(title: "معلومات إضافية", icon: "info.circle") {
                    Toggle("إظهار معلومات المحرك داخل المشغل", isOn: $showPlayerEngineBadge).tint(BlofyTheme.purpleBright)
                    Text("هذا الخيار مخصص للتشخيص فقط، لذلك هو متوقف افتراضيًا.")
                        .font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                }
            }.padding(.bottom, 32)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("المشاهدة")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDelay(_ value: Double) -> String {
        if abs(value) < 1 { return "متزامنة" }
        return value > 0 ? "+\(Int(value / 1000)) ث" : "\(Int(value / 1000)) ث"
    }
}

private struct AdvancedCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(BlofyTheme.textPrimary)
            content
        }.padding(16).blofyPanel(radius: 22).padding(.horizontal, 16)
    }
}
