import SwiftUI

struct LiveFullScreenPlayer: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var session: PlaybackSession
    @State private var programs: [LiveProgram] = []
    @State private var showChannels = false
    @State private var favoritesOnly = false
    @State private var hudVisible = true

    init(initial: PlaybackSession) {
        _session = State(initialValue: initial)
    }

    private var channels: [MediaItem] {
        let base = model.items.filter { $0.kind == .live }
        return favoritesOnly ? base.filter { model.favorites.contains($0.id) } : base
    }

    var body: some View {
        ZStack {
            PlayerScreen(session: session)
                .id(session.id)

            if hudVisible {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Button { dismiss() } label: { liveCircle("xmark") }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.item.name).font(.headline.bold()).lineLimit(1)
                            if let now = programs.first {
                                Text(now.title).font(.caption).foregroundStyle(.white.opacity(0.72)).lineLimit(1)
                            } else {
                                Text("بث مباشر").font(.caption).foregroundStyle(.white.opacity(0.62))
                            }
                        }
                        Spacer()
                        Button { model.toggleFavorite(session.item) } label: {
                            liveCircle(model.favorites.contains(session.item.id) ? "heart.fill" : "heart")
                        }
                        Button { showChannels = true } label: { liveCircle("list.bullet.rectangle.portrait") }
                    }
                    .padding(.horizontal, 16).padding(.top, 10)

                    Spacer()

                    if let now = programs.first {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("الآن · \(now.timeText)").font(.caption2.bold()).foregroundStyle(BlofyTheme.mint)
                            Text(now.title).font(.subheadline.bold()).lineLimit(1)
                            if programs.count > 1 {
                                let next = programs[1]
                                Text("التالي · \(next.timeText) · \(next.title)").font(.caption2).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16).padding(.bottom, 8)
                    }

                    HStack(spacing: 18) {
                        Button { step(-1) } label: { Label("السابق", systemImage: "backward.end.fill") }
                        Button { showChannels = true } label: { Label("القنوات", systemImage: "rectangle.stack.fill") }
                        Button { step(1) } label: { Label("التالي", systemImage: "forward.end.fill") }
                    }
                    .font(.caption.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(.bottom, 24)
                }
                .transition(.opacity)
                .allowsHitTesting(true)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { withAnimation(.easeInOut(duration: 0.16)) { hudVisible.toggle() } })
        .simultaneousGesture(DragGesture(minimumDistance: 45).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            if value.translation.width < -55 { step(1) }
            else if value.translation.width > 55 { step(-1) }
        })
        .task(id: session.item.id) {
            RecentLiveStore.record(session.item)
            programs = await LiveEPGClient.shared.programs(for: session.item, provider: model.selected)
        }
        .sheet(isPresented: $showChannels) {
            NavigationStack {
                List(channels) { item in
                    Button {
                        switchTo(item)
                        showChannels = false
                    } label: {
                        HStack(spacing: 11) {
                            Poster(url: item.poster).frame(width: 54, height: 40).clipShape(RoundedRectangle(cornerRadius: 9))
                            Text(item.name).lineLimit(2)
                            Spacer()
                            if item.id == session.item.id { Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(BlofyTheme.mint) }
                            if model.favorites.contains(item.id) { Image(systemName: "heart.fill").foregroundStyle(BlofyTheme.purpleSoft) }
                        }
                    }.foregroundStyle(.white)
                }
                .scrollContentBackground(.hidden).background(BlofyTheme.backgroundGradient)
                .navigationTitle("القنوات")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("إغلاق") { showChannels = false } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { favoritesOnly.toggle() } label: { Image(systemName: favoritesOnly ? "heart.fill" : "heart") }
                    }
                }
            }.preferredColorScheme(.dark)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private func liveCircle(_ icon: String) -> some View {
        Image(systemName: icon).font(.system(size: 15, weight: .bold)).frame(width: 40, height: 40)
            .background(.black.opacity(0.62), in: Circle()).foregroundStyle(.white)
    }

    private func step(_ delta: Int) {
        let list = channels.isEmpty ? model.items.filter { $0.kind == .live } : channels
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == session.item.id } ?? 0
        let next = (current + delta + list.count) % list.count
        switchTo(list[next])
    }

    private func switchTo(_ item: MediaItem) {
        guard item.id != session.item.id else { return }
        do {
            session = try model.makePlaybackSession(for: item)
            hudVisible = true
        } catch {
            model.error = error.localizedDescription
        }
    }
}
