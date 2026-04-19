import Foundation

nonisolated struct LiveMarket: Decodable, Sendable {
    let id: UUID
    let name: String
    let title: String
    let handle: String
    let xHandle: String
    let imageURL: String
    let avatarURL: String
    let category: String
    let believePool: Double
    let doubtPool: Double
    let volume24h: Double
    let totalVolume: Double
    let holders: Int
    let createdAt: Date
    let priceHistory: [LivePricePoint]
}

nonisolated struct LivePricePoint: Decodable, Sendable {
    let id: UUID
    let date: Date
    let believePrice: Double
    let doubtPrice: Double
}

nonisolated struct LivePosition: Decodable, Sendable {
    let id: UUID
    let marketId: UUID
    let side: String
    let shares: Double
    let avgCost: Double
    let totalInvested: Double
}

nonisolated struct LiveTrade: Decodable, Sendable {
    let id: UUID
    let marketId: UUID
    let side: String
    let amount: Double
    let shares: Double
    let pricePerShare: Double
    let timestamp: Date
}

nonisolated struct LivePortfolio: Decodable, Sendable {
    let balance: Double
    let positions: [LivePosition]
    let trades: [LiveTrade]
}

nonisolated struct LiveTradeResult: Decodable, Sendable {
    let shares: Double
    let avgPrice: Double
    let fee: Double
    let balance: Double
    let amount: Double?
    let payout: Double?
}

nonisolated struct LiveDepositResult: Decodable, Sendable {
    let balance: Double
}

nonisolated struct LiveProfile: Decodable, Sendable {
    let wallet: String
    let username: String
    let bio: String
    let avatarURL: String
}

nonisolated struct LiveLeveragePosition: Decodable, Identifiable, Sendable {
    let id: UUID
    let marketId: UUID
    let side: String
    let leverage: Double
    let collateral: Double
    let size: Double
    let entryPrice: Double
    let liquidationPrice: Double
    let status: String
    let opened_at: Date
    let closed_at: Date?
    let closePnL: Double?
}

nonisolated struct LiveOpenLeverageResult: Decodable, Sendable {
    let id: UUID
    let entryPrice: Double
    let liquidationPrice: Double
    let size: Double
    let balance: Double
}

nonisolated struct LiveCloseLeverageResult: Decodable, Sendable {
    let pnl: Double
    let payout: Double
    let balance: Double
}

nonisolated struct LiveTopTrader: Decodable, Identifiable, Sendable {
    let wallet: String
    let username: String
    let avatarURL: String
    let volume: Double
    let tradeCount: Int
    let realizedPnL: Double
    var id: String { wallet }
}

nonisolated enum LiveServiceError: Error, Sendable {
    case notConfigured
    case invalidURL
    case requestFailed(String)
    case decodingFailed
}

nonisolated struct LiveService: Sendable {
    @MainActor static var baseURL: String { Config.allValues["EXPO_PUBLIC_SUPABASE_URL"] ?? "" }
    @MainActor static var anonKey: String { Config.allValues["EXPO_PUBLIC_SUPABASE_ANON_KEY"] ?? "" }

    @MainActor static var isConfigured: Bool {
        !baseURL.isEmpty && !anonKey.isEmpty
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            let isoFractional = ISO8601DateFormatter()
            isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = isoFractional.date(from: s) { return d }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: s) { return d }
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
            if let d = df.date(from: s) { return d }
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
            if let d = df.date(from: s) { return d }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(s)")
        }
        return d
    }

    private static func rpc<T: Decodable>(_ name: String, body: [String: Any]) async throws -> T {
        let cfg = await MainActor.run { (baseURL: baseURL, anonKey: anonKey) }
        guard !cfg.baseURL.isEmpty && !cfg.anonKey.isEmpty else { throw LiveServiceError.notConfigured }
        guard let url = URL(string: "\(cfg.baseURL)/rest/v1/rpc/\(name)") else {
            throw LiveServiceError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue(cfg.anonKey, forHTTPHeaderField: "apikey")
        req.addValue("Bearer \(cfg.anonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw LiveServiceError.requestFailed("no response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "http \(http.statusCode)"
            throw LiveServiceError.requestFailed(msg)
        }
        do {
            return try decoder().decode(T.self, from: data)
        } catch {
            throw LiveServiceError.decodingFailed
        }
    }

    static func getMarkets() async throws -> [LiveMarket] {
        try await rpc("get_markets", body: [:])
    }

    static func getPortfolio(wallet: String) async throws -> LivePortfolio {
        try await rpc("get_portfolio", body: ["p_wallet": wallet])
    }

    static func deposit(wallet: String, amount: Double) async throws -> LiveDepositResult {
        try await rpc("deposit", body: ["p_wallet": wallet, "p_amount": amount])
    }

    static func withdraw(wallet: String, amount: Double) async throws -> LiveDepositResult {
        try await rpc("withdraw", body: ["p_wallet": wallet, "p_amount": amount])
    }

    static func buy(wallet: String, marketId: UUID, side: String, amount: Double) async throws -> LiveTradeResult {
        try await rpc("execute_trade", body: [
            "p_wallet": wallet,
            "p_market_id": marketId.uuidString.lowercased(),
            "p_side": side,
            "p_is_buy": true,
            "p_amount": amount,
            "p_shares": 0
        ])
    }

    static func getProfile(wallet: String) async throws -> LiveProfile {
        try await rpc("get_profile", body: ["p_wallet": wallet])
    }

    static func upsertProfile(wallet: String, username: String, bio: String, avatarURL: String) async throws -> LiveProfile {
        try await rpc("upsert_profile", body: [
            "p_wallet": wallet,
            "p_username": username,
            "p_bio": bio,
            "p_avatar_url": avatarURL
        ])
    }

    static func getTopTraders() async throws -> [LiveTopTrader] {
        try await rpc("get_top_traders", body: [:])
    }

    static func openLeverage(wallet: String, marketId: UUID, side: String, leverage: Double, collateral: Double) async throws -> LiveOpenLeverageResult {
        try await rpc("open_leverage", body: [
            "p_wallet": wallet,
            "p_market_id": marketId.uuidString.lowercased(),
            "p_side": side,
            "p_leverage": leverage,
            "p_collateral": collateral
        ])
    }

    static func closeLeverage(wallet: String, id: UUID) async throws -> LiveCloseLeverageResult {
        try await rpc("close_leverage", body: [
            "p_wallet": wallet,
            "p_id": id.uuidString.lowercased()
        ])
    }

    static func getLeverage(wallet: String) async throws -> [LiveLeveragePosition] {
        try await rpc("get_leverage", body: ["p_wallet": wallet])
    }

    static func liquidateUnderwater() async throws -> Int {
        try await rpc("liquidate_underwater", body: [:])
    }

    static func sell(wallet: String, marketId: UUID, side: String, shares: Double) async throws -> LiveTradeResult {
        try await rpc("execute_trade", body: [
            "p_wallet": wallet,
            "p_market_id": marketId.uuidString.lowercased(),
            "p_side": side,
            "p_is_buy": false,
            "p_amount": 0,
            "p_shares": shares
        ])
    }
}
