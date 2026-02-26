import Foundation
import CryptoKit

// MARK: - Token Validation
extension TeslaTokens {
    var isExpired: Bool {
        // Simple check - in production, would parse JWT and check exp claim
        // For now, we'll rely on the API returning 401 and triggering refresh
        return false
    }
}

// MARK: - Code Verifier & Challenge Generation
struct PKCEHelper {
    static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Object Comparison
struct DiffGenerator {
    static func compareObjects(_ old: CombinedOrder, _ new: CombinedOrder) -> [String: OrderDiff.DiffValue] {
        var changes: [String: OrderDiff.DiffValue] = [:]
        
        // Compare basic order fields
        if old.order.orderStatus != new.order.orderStatus {
            changes["order.orderStatus"] = OrderDiff.DiffValue(
                old: AnyCodableValue(old.order.orderStatus),
                new: AnyCodableValue(new.order.orderStatus)
            )
        }
        
        if old.order.vin != new.order.vin {
            changes["order.vin"] = OrderDiff.DiffValue(
                old: AnyCodableValue(old.order.vin ?? ""),
                new: AnyCodableValue(new.order.vin ?? "")
            )
        }
        
        if old.order.mktOptions != new.order.mktOptions {
            changes["order.mktOptions"] = OrderDiff.DiffValue(
                old: AnyCodableValue(old.order.mktOptions ?? ""),
                new: AnyCodableValue(new.order.mktOptions ?? "")
            )
        }
        
        // Compare deep nested properties in tasks
        compareTaskProperties(old: old.details.tasks, new: new.details.tasks, changes: &changes)
        
        return changes
    }
    
    private static func compareTaskProperties(old: [String: AnyCodableValue], new: [String: AnyCodableValue], changes: inout [String: OrderDiff.DiffValue]) {
        // Helper to extract nested values safely
        func getValue(from dict: [String: AnyCodableValue], path: [String]) -> AnyCodableValue? {
            var current: Any = dict
            for key in path {
                if let dict = current as? [String: AnyCodableValue] {
                    guard let next = dict[key] else { return nil }
                    current = next.value
                } else if let dict = current as? [String: Any] {
                    guard let next = dict[key] else { return nil }
                    current = next
                } else {
                    return nil
                }
            }
            return AnyCodableValue(current)
        }
        
        // Define paths to compare
        let pathsToCompare: [[String]] = [
            ["deliveryDetails", "regData", "reggieLicensePlate"],
            ["scheduling", "deliveryWindowDisplay"],
            ["scheduling", "apptDateTimeAddressStr"],
            ["scheduling", "deliveryType"],
            ["scheduling", "deliveryAddressTitle"],
            ["finalPayment", "data", "etaToDeliveryCenter"],
            ["registration", "orderDetails", "vehicleRoutingLocation"],
            ["registration", "orderDetails", "vehicleOdometer"],
            ["registration", "orderDetails", "reservationDate"],
            ["registration", "orderDetails", "orderBookedDate"]
        ]
        
        for path in pathsToCompare {
            let oldValue = getValue(from: old, path: path)
            let newValue = getValue(from: new, path: path)
            
            if let oldVal = oldValue, let newVal = newValue, oldVal != newVal {
                let key = "details.tasks." + path.joined(separator: ".")
                changes[key] = OrderDiff.DiffValue(old: oldVal, new: newVal)
            }
        }
    }
}

// MARK: - Date Formatting
extension Date {
    func formatted(as style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    func formattedWithTime(dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: self)
    }
}

// MARK: - Model Code Normalization
extension String {
    func normalizedTeslaModelCode() -> String {
        let code = self.lowercased().replacingOccurrences(of: "model ", with: "").trimmingCharacters(in: .whitespaces)
        
        switch code {
        case "ms", "s": return "S"
        case "m3", "3": return "3"
        case "mx", "x": return "X"
        case "my", "y": return "Y"
        case "ct", "cybertruck": return "CYBERTRUCK"
        default:
            let upperCode = self.uppercased()
            return FallbackCarImages.urls.keys.contains(upperCode) ? upperCode : self
        }
    }
    
    func teslaModelAPICode() -> String? {
        let code = self.lowercased().replacingOccurrences(of: "model ", with: "").trimmingCharacters(in: .whitespaces)
        
        switch code {
        case "ms", "s": return "ms"
        case "m3", "3": return "m3"
        case "mx", "x": return "mx"
        case "my", "y": return "my"
        case "ct", "cybertruck": return "ct"
        default: return nil
        }
    }
}

// MARK: - Safe Storage Operations
extension UserDefaults {
    func safelySet<T: Encodable>(_ value: T, forKey key: String) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            set(data, forKey: key)
            return true
        } catch {
            print("Failed to encode value for key \(key): \(error)")
            return false
        }
    }
    
    func safelyGet<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to decode value for key \(key): \(error)")
            return nil
        }
    }
}
