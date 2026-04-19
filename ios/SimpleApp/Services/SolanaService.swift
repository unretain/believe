import Foundation

nonisolated struct SolanaRPCRequest: Encodable, Sendable {
    let jsonrpc: String = "2.0"
    let id: Int = 1
    let method: String
    let params: [String]
}

nonisolated struct SolanaRPCResponse: Decodable, Sendable {
    let result: BalanceResult?

    struct BalanceResult: Decodable, Sendable {
        let value: UInt64
    }
}

nonisolated enum SolanaServiceError: Error, Sendable {
    case invalidURL
    case requestFailed
    case decodingFailed
}

nonisolated struct SolanaService: Sendable {
    static let rpcURL = "https://api.mainnet-beta.solana.com"
    static let lamportsPerSOL: Double = 1_000_000_000

    static func getBalance(address: String) async throws -> Double {
        guard let url = URL(string: rpcURL) else { throw SolanaServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = SolanaRPCRequest(method: "getBalance", params: [address])
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SolanaServiceError.requestFailed
        }

        let rpcResponse = try JSONDecoder().decode(SolanaRPCResponse.self, from: data)
        guard let result = rpcResponse.result else { throw SolanaServiceError.decodingFailed }

        return Double(result.value) / lamportsPerSOL
    }
}
