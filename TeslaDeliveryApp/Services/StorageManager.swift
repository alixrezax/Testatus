import Foundation
import Security

// MARK: - Storage Manager
class StorageManager {
    static let shared = StorageManager()
    
    private init() {}
    
    // MARK: - Keychain Storage (for sensitive tokens)
    
    func saveTokensToKeychain(_ tokens: TeslaTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: StorageKey.teslaTokens,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "StorageManager", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save tokens to keychain"])
        }
    }
    
    func loadTokensFromKeychain() throws -> TeslaTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: StorageKey.teslaTokens,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw NSError(domain: "StorageManager", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to load tokens from keychain"])
        }
        
        guard let data = result as? Data else {
            return nil
        }
        
        return try JSONDecoder().decode(TeslaTokens.self, from: data)
    }
    
    func deleteTokensFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: StorageKey.teslaTokens
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Order History Storage (in Documents directory)
    
    private func getHistoryFileURL(for orderReference: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("order_history_\(orderReference).json")
    }
    
    func saveOrderHistory(_ history: [HistoricalSnapshot], for orderReference: String) throws {
        let url = getHistoryFileURL(for: orderReference)
        let data = try JSONEncoder().encode(history)
        try data.write(to: url)
    }
    
    func loadOrderHistory(for orderReference: String) throws -> [HistoricalSnapshot] {
        let url = getHistoryFileURL(for: orderReference)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([HistoricalSnapshot].self, from: data)
    }
    
    func appendToOrderHistory(_ snapshot: HistoricalSnapshot, for orderReference: String) throws {
        var history = try loadOrderHistory(for: orderReference)
        history.append(snapshot)
        
        // Keep only the last MAX_HISTORY_ENTRIES
        if history.count > AppConstants.maxHistoryEntries {
            history = Array(history.suffix(AppConstants.maxHistoryEntries))
        }
        
        try saveOrderHistory(history, for: orderReference)
    }
    
    // MARK: - Checklist Storage (in UserDefaults)
    
    func saveChecklistProgress(_ items: [ChecklistItem], for orderReference: String) {
        let key = StorageKey.checklistPrefix + orderReference
        _ = UserDefaults.standard.safelySet(items, forKey: key)
    }
    
    func loadChecklistProgress(for orderReference: String) -> [ChecklistItem]? {
        let key = StorageKey.checklistPrefix + orderReference
        return UserDefaults.standard.safelyGet([ChecklistItem].self, forKey: key)
    }
    
    // MARK: - Auth State Storage (temporary, in UserDefaults)
    
    func saveCodeVerifier(_ verifier: String) {
        UserDefaults.standard.set(verifier, forKey: StorageKey.codeVerifier)
    }
    
    func loadCodeVerifier() -> String? {
        return UserDefaults.standard.string(forKey: StorageKey.codeVerifier)
    }
    
    func deleteCodeVerifier() {
        UserDefaults.standard.removeObject(forKey: StorageKey.codeVerifier)
    }
    
    func saveAuthState(_ state: String) {
        UserDefaults.standard.set(state, forKey: StorageKey.authState)
    }
    
    func loadAuthState() -> String? {
        return UserDefaults.standard.string(forKey: StorageKey.authState)
    }
    
    func deleteAuthState() {
        UserDefaults.standard.removeObject(forKey: StorageKey.authState)
    }
    
    // MARK: - Clear All Data (for logout)
    
    func clearAllData() {
        deleteTokensFromKeychain()
        deleteCodeVerifier()
        deleteAuthState()
        // Note: We keep order history and checklist data for better UX
    }
}
