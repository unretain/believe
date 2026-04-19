import SwiftUI

struct ContentView: View {
    @State private var viewModel = MarketViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Markets", systemImage: "chart.line.uptrend.xyaxis", value: 0) {
                NavigationStack {
                    FeedView(viewModel: viewModel)
                        .navigationTitle("Sentiment")
                        .navigationDestination(for: UUID.self) { marketId in
                            MarketDetailView(marketId: marketId, viewModel: viewModel)
                        }
                }
            }

            Tab("Search", systemImage: "magnifyingglass", value: 1) {
                NavigationStack {
                    SearchView(viewModel: viewModel)
                        .navigationTitle("Search")
                        .searchable(text: $viewModel.searchText, prompt: "Search markets...")
                        .navigationDestination(for: UUID.self) { marketId in
                            MarketDetailView(marketId: marketId, viewModel: viewModel)
                        }
                }
            }

            Tab("Leaderboard", systemImage: "trophy", value: 2) {
                NavigationStack {
                    LeaderboardView(viewModel: viewModel)
                        .navigationTitle("Leaderboard")
                }
            }

            Tab("Portfolio", systemImage: "briefcase", value: 3) {
                NavigationStack {
                    PortfolioView(viewModel: viewModel)
                        .navigationTitle("Portfolio")
                }
            }

            Tab("Wallet", systemImage: "wallet.bifold", value: 4) {
                NavigationStack {
                    WalletView(viewModel: viewModel)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
