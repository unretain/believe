import Foundation

struct SampleData {
    static let initialLiquidity: Double = 1000

    private static func generatePriceHistory(points: Int, targetBelieve: Double, volatility: Double, seed: UInt64) -> [PricePoint] {
        var rng = SeededRNG(seed: seed)
        var result: [PricePoint] = []
        var believe = 0.5
        let now = Date()
        let step: TimeInterval = 3600
        for i in 0..<points {
            let t = Double(i) / Double(max(1, points - 1))
            let target = 0.5 + (targetBelieve - 0.5) * t
            let noise = (rng.nextDouble() - 0.5) * 2 * volatility
            believe += (target - believe) * 0.15 + noise
            believe = min(max(believe, 0.05), 0.95)
            let date = now.addingTimeInterval(-Double(points - 1 - i) * step)
            result.append(PricePoint(date: date, believePrice: believe, doubtPrice: 1 - believe))
        }
        return result
    }

    static let markets: [Market] = {
        let configs: [(name: String, title: String, handle: String, xHandle: String, category: MarketCategory, believe: Double, avatar: String)] = [
            ("Ben Pasternak", "Entrepreneur", "@bfrfrfrfr", "@bfrfrfrfr", .tech, 0.68, "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/g7d124v0loog19flgnndi.png"),
            ("Elon Musk", "CEO, Tesla & SpaceX", "@elonmusk", "@elonmusk", .tech, 0.61, "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/jk7sz6p9e8pozpiudiipj.png"),
            ("Taylor Swift", "Artist & Songwriter", "@taylorswift", "@taylorswift13", .entertainment, 0.54, "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/ov3iy2irr6511okrda3uj.png"),
            ("MrBeast", "YouTuber & Philanthropist", "@mrbeast", "@MrBeast", .creators, 0.81, "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/y1eg93i4ejp56w7x6eyhm.png"),
            ("LeBron James", "NBA Player", "@kingjames", "@KingJames", .sports, 0.50, "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/d8h5vnqfaf6mxpa6e3sn6.png"),
            ("Vitalik Buterin", "Ethereum Co-Founder", "@vitalik", "@VitalikButerin", .crypto, 0.63, "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/4u8tjahknefpfkqqnnolh.png"),
            ("Alexandria O-C", "U.S. Representative", "@aoc", "@AOC", .politics, 0.38, "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/8p8nyb5cjoiyedm531mq9.png"),
            ("Charli D'Amelio", "Content Creator", "@charlidamelio", "@charlidamelio", .creators, 0.61, "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/snv3l7esbs1t35nist6ao.png"),
            ("Bitcoin", "BTC · Digital Gold", "$BTC", "$BTC_coin", .crypto, 0.65, "https://assets.coingecko.com/coins/images/1/large/bitcoin.png"),
            ("Ethereum", "ETH · Smart Contracts", "$ETH", "$ETH_coin", .crypto, 0.60, "https://assets.coingecko.com/coins/images/279/large/ethereum.png"),
            ("Solana", "SOL · High-speed L1", "$SOL", "$SOL_coin", .crypto, 0.67, "https://assets.coingecko.com/coins/images/4128/large/solana.png"),
            ("Dogecoin", "DOGE · The people's coin", "$DOGE", "$DOGE_coin", .crypto, 0.48, "https://assets.coingecko.com/coins/images/5/large/dogecoin.png"),
            ("LA Lakers", "NBA · Los Angeles", "@Lakers", "@Lakers", .sports, 0.54, "https://a.espncdn.com/i/teamlogos/nba/500/lal.png"),
            ("Golden State Warriors", "NBA · Bay Area", "@warriors", "@warriors", .sports, 0.56, "https://a.espncdn.com/i/teamlogos/nba/500/gs.png"),
            ("Dallas Cowboys", "NFL · America's Team", "@dallascowboys", "@dallascowboys", .sports, 0.49, "https://a.espncdn.com/i/teamlogos/nfl/500/dal.png"),
            ("Kansas City Chiefs", "NFL · Super Bowl reign", "@Chiefs", "@Chiefs", .sports, 0.62, "https://a.espncdn.com/i/teamlogos/nfl/500/kc.png"),
            ("Real Madrid", "La Liga · Los Blancos", "@realmadrid", "@realmadrid", .sports, 0.65, "https://a.espncdn.com/i/teamlogos/soccer/500/86.png"),
            ("Manchester City", "EPL · The Citizens", "@ManCity", "@ManCity", .sports, 0.60, "https://a.espncdn.com/i/teamlogos/soccer/500/382.png"),
            ("New York Yankees", "MLB · The Bronx Bombers", "@Yankees", "@Yankees", .sports, 0.55, "https://a.espncdn.com/i/teamlogos/mlb/500/nyy.png"),
            ("Sam Altman", "CEO, OpenAI", "@sama", "@sama", .tech, 0.68, "https://pbs.twimg.com/profile_images/1843893113242415104/_adMgDjA_400x400.jpg"),
            ("Mark Zuckerberg", "CEO, Meta", "@zuck", "@finkd", .tech, 0.53, "https://pbs.twimg.com/profile_images/1822982765685108736/XQ2WBq7E_400x400.jpg"),
            ("Donald Trump", "45th & 47th President", "@realDonaldTrump", "@realDonaldTrump", .politics, 0.55, "https://pbs.twimg.com/profile_images/874276197357596672/kUuht00m_400x400.jpg"),
            ("Drake", "OVO · 6 God", "@Drake", "@Drake", .entertainment, 0.59, "https://pbs.twimg.com/profile_images/1788574997213835264/1Z2FGI0i_400x400.jpg"),
        ]

        return configs.enumerated().map { idx, c in
            let pool = initialLiquidity / 2.0
            let believePool = pool * ((1 - c.believe) / 0.5)
            let doubtPool = pool * (c.believe / 0.5)
            let total = believePool + doubtPool
            let anchor = PricePoint(
                date: Date(),
                believePrice: doubtPool / total,
                doubtPrice: believePool / total
            )
            let avatar = c.avatar
            return Market(
                id: UUID(),
                name: c.name,
                title: c.title,
                handle: c.handle,
                xHandle: c.xHandle,
                imageURL: avatar,
                avatarURL: avatar,
                category: c.category,
                believePool: believePool,
                doubtPool: doubtPool,
                volume24h: 0,
                totalVolume: 0,
                holders: 0,
                priceHistory: [anchor],
                createdAt: Date().addingTimeInterval(-Double((idx + 1) * 86_400))
            )
        }
    }()
}

private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
    mutating func nextDouble() -> Double {
        Double(next() % 10_000) / 10_000.0
    }
}
