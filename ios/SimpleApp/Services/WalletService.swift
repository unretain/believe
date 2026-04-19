import Foundation
import CryptoKit
import Security

@Observable
@MainActor
class WalletService {
    var publicAddress: String = ""
    var solBalance: Double = 0.0
    var tradingBalance: Double = 0.0
    var isLoadingBalance: Bool = false
    var balanceError: String?

    private let keychainAccount = "com.sentiment.solana.privatekey"
    private var privateKeyBytes: [UInt8] = []

    init() {
        loadOrCreateWallet()
    }

    func loadOrCreateWallet() {
        if let existingKey = loadKeyFromKeychain() {
            privateKeyBytes = existingKey
        } else {
            let newKey = generateEd25519PrivateKey()
            privateKeyBytes = newKey
            saveKeyToKeychain(newKey)
        }
        derivePublicAddress()
    }

    func refreshBalance() async {
        isLoadingBalance = true
        balanceError = nil
        do {
            solBalance = try await SolanaService.getBalance(address: publicAddress)
        } catch {
            balanceError = "Could not fetch balance"
        }
        isLoadingBalance = false
    }

    private func generateEd25519PrivateKey() -> [UInt8] {
        let privateKey = Curve25519.Signing.PrivateKey()
        return Array(privateKey.rawRepresentation)
    }

    private func derivePublicAddress() {
        guard !privateKeyBytes.isEmpty else { return }
        do {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
            let publicKeyBytes = Array(privateKey.publicKey.rawRepresentation)
            publicAddress = Base58.encode(publicKeyBytes)
        } catch {
            publicAddress = ""
        }
    }

    private func saveKeyToKeychain(_ key: [UInt8]) {
        let data = Data(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadKeyFromKeychain() -> [UInt8]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return Array(data)
    }

    func resetWallet() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        privateKeyBytes = []
        publicAddress = ""
        solBalance = 0.0
        loadOrCreateWallet()
    }
}
