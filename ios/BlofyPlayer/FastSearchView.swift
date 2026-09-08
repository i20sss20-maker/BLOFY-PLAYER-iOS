import SwiftUI

struct FastSearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var results: [MediaItem] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var generation = UUID()

    var body: some View {
        NavigationStack {
            List(results) { item in
                NavigationLink {
                    if item.kind == .series { SeriesDetailsView(series: item) }
                    else { DetailsView(item: item) }
                } label: {
                    HStack(spacing: 12) {
                        Poster(url: item.poster)
                            .frame(width: 58, height: item.kind == .live ? 48 : 78)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(BlofyTheme.textPrimary)
                                .lineLimit(2)
                            Text(item.kind.title)
                                .font(.caption)
                                .foregroundStyle(BlofyTheme.purpleSoft)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(BlofyTheme.surface.opacity(0.82))
            }
            .overlay {
                if searching {
                    VStack(spacing: 10) {
                        ProgressView().tint(BlofyTheme.purpleBright)
                        Text("جاري البحث…").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                    }
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 34))
                            .foregroundStyle(BlofyTheme.textMuted)
                        Text("ابحث عن أي محتوى")
                            .font(.headline)
                            .foregroundStyle(BlofyTheme.textPrimary)
                        Text("اكتب اسم القناة أو الفيلم أو المسلسل.")
                            .font(.caption)
                            .foregroundStyle(BlofyTheme.textMuted)
                    }
                } else if results.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 34))
                            .foregroundStyle(BlofyTheme.textMuted)
                        Text("ما لقينا نتائج")
                            .font(.headline)
                            .foregroundStyle(BlofyTheme.textPrimary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BlofyTheme.backgroundGradient)
            .navigationTitle("البحث")
            .searchable(text: $query, prompt: "اكتب للبحث")
            .onChange(of: query) { value in
                scheduleSearch(value)
            }
            .onChange(of: model.items.count) { _ in
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    scheduleSearch(query, debounceNanoseconds: 80_000_000)
                }
            }
            .onDisappear {
                searchTask?.cancel()
                generation = UUID()
            }
        }
    }

    private func scheduleSearch(_ raw: String, debounceNanoseconds: UInt64 = 180_000_000) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let ticket = UUID()
        generation = ticket

        guard !trimmed.isEmpty else {
            searching = false
            results = []
            return
        }

        searching = true
        let snapshot = model.items
        let sourceID = model.selected?.id

        searchTask = Task {
            do { try await Task.sleep(nanoseconds: debounceNanoseconds) }
            catch { return }
            guard !Task.isCancelled else { return }

            let found = await MediaSearchEngine.shared.search(
                items: snapshot,
                query: trimmed,
                sourceID: sourceID,
                limit: 120
            )

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard generation == ticket else { return }
                results = found
                searching = false
            }
        }
    }
}
