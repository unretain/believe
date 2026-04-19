import Foundation

struct PersistenceService {
    private static let marketsKey = "sentiment_markets"
    private static let accountKey = "sentiment_account"

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func fileURL(for key: String) -> URL {
        documentsURL.appendingPathComponent("\(key).json")
    }

    static func saveMarkets(_ markets: [Market]) {
        save(markets, key: marketsKey)
    }

    static func loadMarkets() -> [Market]? {
        load([Market].self, key: marketsKey)
    }

    static func saveAccount(_ account: UserAccount) {
        save(account, key: accountKey)
    }

    static func loadAccount() -> UserAccount? {
        load(UserAccount.self, key: accountKey)
    }

    static func resetAll() {
        try? FileManager.default.removeItem(at: fileURL(for: marketsKey))
        try? FileManager.default.removeItem(at: fileURL(for: accountKey))
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}
