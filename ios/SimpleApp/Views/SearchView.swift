import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: MarketViewModel
    @State private var categoryFilter: MarketCategory?

    private var results: [Market] {
        var r = viewModel.markets
        if let cat = categoryFilter {
            r = r.filter { $0.category == cat }
        }
        if !viewModel.searchText.isEmpty {
            let q = viewModel.searchText
            r = r.filter {
                $0.name.localizedCaseInsensitiveContains(q) ||
                $0.title.localizedCaseInsensitiveContains(q) ||
                $0.handle.localizedCaseInsensitiveContains(q) ||
                $0.xHandle.localizedCaseInsensitiveContains(q) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(q)
            }
        }
        return r
    }

    var body: some View {
        List {
            if viewModel.searchText.isEmpty && categoryFilter == nil {
                Section("Popular") {
                    ForEach(viewModel.trendingMarkets.prefix(5)) { market in
                        NavigationLink(value: market.id) {
                            searchRow(market: market)
                        }
                    }
                }

                Section("Categories") {
                    ForEach(MarketCategory.allCases.filter { $0 != .all && $0 != .trending }, id: \.self) { category in
                        Button {
                            categoryFilter = category
                        } label: {
                            HStack {
                                Image(systemName: iconForCategory(category))
                                    .frame(width: 28)
                                    .foregroundStyle(.blue)
                                Text(category.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } else {
                if let cat = categoryFilter {
                    Section {
                        Button {
                            categoryFilter = nil
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                Text("\(cat.rawValue)")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("Clear")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                ForEach(results) { market in
                    NavigationLink(value: market.id) {
                        searchRow(market: market)
                    }
                }

                if results.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func searchRow(market: Market) -> some View {
        HStack(spacing: 12) {
            Color(.secondarySystemBackground)
                .frame(width: 40, height: 40)
                .overlay {
                    AsyncImage(url: URL(string: market.avatarURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(market.name)
                    .font(.subheadline.bold())
                Text(market.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(market.believePercentage)%")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
        }
    }

    private func iconForCategory(_ category: MarketCategory) -> String {
        switch category {
        case .all: return "square.grid.2x2"
        case .trending: return "flame"
        case .tech: return "laptopcomputer"
        case .entertainment: return "star"
        case .sports: return "sportscourt"
        case .politics: return "building.columns"
        case .crypto: return "bitcoinsign.circle"
        case .creators: return "video"
        }
    }
}
