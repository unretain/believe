import Foundation

nonisolated struct PricePoint: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let believePrice: Double
    let doubtPrice: Double

    init(id: UUID = UUID(), date: Date, believePrice: Double, doubtPrice: Double) {
        self.id = id
        self.date = date
        self.believePrice = believePrice
        self.doubtPrice = doubtPrice
    }
}

nonisolated struct Market: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let title: String
    let handle: String
    let xHandle: String
    let imageURL: String
    let avatarURL: String
    let category: MarketCategory
    var believePool: Double
    var doubtPool: Double
    var volume24h: Double
    var totalVolume: Double
    var holders: Int
    var priceHistory: [PricePoint]
    let createdAt: Date

    var k: Double { believePool * doubtPool }

    var currentBelieve: Double {
        let total = believePool + doubtPool
        guard total > 0 else { return 0.5 }
        return doubtPool / total
    }

    var currentDoubt: Double {
        let total = believePool + doubtPool
        guard total > 0 else { return 0.5 }
        return believePool / total
    }

    var believePercentage: Int {
        Int(currentBelieve * 100)
    }

    var change24h: Double {
        guard priceHistory.count >= 2 else { return 0 }
        let latest = priceHistory.last!.believePrice
        let cutoffIndex = max(0, priceHistory.count - 24)
        let earlier = priceHistory[cutoffIndex].believePrice
        guard earlier > 0 else { return 0 }
        return ((latest - earlier) / earlier) * 100
    }

    var isTrending: Bool {
        abs(change24h) > 3.0 || volume24h > 100
    }

    mutating func recordPrice() {
        let point = PricePoint(
            date: Date(),
            believePrice: currentBelieve,
            doubtPrice: currentDoubt
        )
        priceHistory.append(point)
        if priceHistory.count > 200 {
            priceHistory.removeFirst(priceHistory.count - 200)
        }
    }
}

nonisolated enum MarketCategory: String, CaseIterable, Codable, Sendable {
    case all = "All"
    case trending = "Trending"
    case tech = "Tech"
    case entertainment = "Entertainment"
    case sports = "Sports"
    case politics = "Politics"
    case crypto = "Crypto"
    case creators = "Creators"
}

nonisolated enum TimeRange: String, CaseIterable, Sendable {
    case oneHour = "1H"
    case oneDay = "1D"
    case oneWeek = "1W"
    case oneMonth = "1M"
    case all = "ALL"
}

nonisolated enum TradeSide: String, Codable, Sendable {
    case believe = "Believe"
    case doubt = "Doubt"
}
