import SwiftUI

struct FastSearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var results: [MediaItem] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?

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
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    private func scheduleSearch(_ raw: String) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searching = false
            results = []
            return
        }

        searching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 380_000_000)
            guard !Task.isCancelled else { return }
            let needle = normalizedSearch(trimmed)
            let snapshot = model.items

            var found: [MediaItem] = []
            found.reserveCapacity(80)
            for item in snapshot {
                if Task.isCancelled { return }
                if normalizedSearch(item.name).contains(needle) {
                    found.append(item)
                    if found.count >= 120 { break }
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                results = found
                searching = false
            }
        }
    }
}
