import SwiftUI

struct PlayerAdvancedSettingsView: View {
    @AppStorage("preferredAudioLanguage") private var preferredAudioLanguage = "auto"
    @AppStorage("preferredSubtitleLanguage") private var preferredSubtitleLanguage = "auto"
    @AppStorage("autoEnableSubtitles") private var autoEnableSubtitles = false
    @AppStorage("subtitleScale") private var subtitleScale = 1.0
    @AppStorage("subtitleDelayMs") private var subtitleDelayMs = 0.0
    @AppStorage("defaultPlaybackRate") private var defaultPlaybackRate = 1.0
    @AppStorage("videoAspectMode") private var videoAspectMode = "fit"
    @AppStorage("showPlayerEngineBadge") private var showPlayerEngineBadge = true
    @AppStorage("rememberTrackSelection") private var rememberTrackSelection = true
    @AppStorage("lastAudioTrackName") private var lastAudioTrackName = ""
    @AppStorage("lastSubtitleTrackName") private var lastSubtitleTrackName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    BlofyBrandMark(compact: true)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("إعدادات المشغل").font(.title2.bold())
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
                        Text("آخر مسار: \(lastAudioTrackName)").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                    }
                }

                AdvancedCard(title: "الترجمة", icon: "captions.bubble.fill") {
                    Toggle("تشغيل الترجمة تلقائيًا", isOn: $autoEnableSubtitles).tint(BlofyTheme.purpleBright)
                    Divider().overlay(BlofyTheme.divider)
                    Text("لغة الترجمة المفضلة").font(.subheadline.bold())
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
                        HStack { Text("تأخير الترجمة"); Spacer(); Text("\(Int(subtitleDelayMs)) ms").foregroundStyle(BlofyTheme.purpleSoft) }
                        Slider(value: $subtitleDelayMs, in: -5000...5000, step: 250).tint(BlofyTheme.purpleBright)
                    }
                    if rememberTrackSelection && !lastSubtitleTrackName.isEmpty {
                        Text("آخر ترجمة: \(lastSubtitleTrackName)").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                    }
                }

                AdvancedCard(title: "الصورة والتشغيل", icon: "rectangle.inset.filled") {
                    Text("نسبة عرض الفيديو").font(.subheadline.bold())
                    Picker("نسبة العرض", selection: $videoAspectMode) {
                        Text("احتواء").tag("fit")
                        Text("ملء").tag("fill")
                        Text("16:9").tag("16:9")
                    }.pickerStyle(.segmented)
                    Divider().overlay(BlofyTheme.divider)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("السرعة الافتراضية"); Spacer(); Text(String(format: "%.2fx", defaultPlaybackRate)).foregroundStyle(BlofyTheme.purpleSoft) }
                        Slider(value: $defaultPlaybackRate, in: 0.5...2.0, step: 0.25).tint(BlofyTheme.purpleBright)
                    }
                    Toggle("إظهار اسم المحرك أثناء التشغيل", isOn: $showPlayerEngineBadge).tint(BlofyTheme.purpleBright)
                    Toggle("تذكر آخر مسار صوت وترجمة", isOn: $rememberTrackSelection).tint(BlofyTheme.purpleBright)
                }

                AdvancedCard(title: "اختصارات أثناء المشاهدة", icon: "hand.tap.fill") {
                    PlayerShortcutRow(icon: "gobackward.10", title: "رجوع 10 ثوانٍ", subtitle: "زر سريع للأفلام والحلقات")
                    Divider().overlay(BlofyTheme.divider)
                    PlayerShortcutRow(icon: "goforward.10", title: "تقديم 10 ثوانٍ", subtitle: "بدون فتح قائمة إضافية")
                    Divider().overlay(BlofyTheme.divider)
                    PlayerShortcutRow(icon: "captions.bubble", title: "ترجمة", subtitle: "اختيار المسار مباشرة")
                    Divider().overlay(BlofyTheme.divider)
                    PlayerShortcutRow(icon: "speaker.wave.2", title: "صوت", subtitle: "تبديل المسار واللغة")
                }
            }.padding(.bottom, 32)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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

private struct PlayerShortcutRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 30).foregroundStyle(BlofyTheme.purpleBright)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            }
        }
    }
}
