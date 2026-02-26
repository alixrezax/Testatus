import Foundation

// MARK: - Tesla OAuth Tokens
struct TeslaTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let scope: String?  // Optional - not always returned
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}

// MARK: - Tesla Order
struct TeslaOrder: Codable {
    let referenceNumber: String
    let orderStatus: String
    let modelCode: String
    let vin: String?
    let isB2b: Bool?
    let ownerCompanyName: String?
    let isUsed: Bool?
    let mktOptions: String?
    
    enum CodingKeys: String, CodingKey {
        case referenceNumber, orderStatus, modelCode, vin, isB2b, ownerCompanyName, isUsed, mktOptions
    }
}

// MARK: - Tesla Task Card
struct TeslaTaskCard: Codable {
    let title: String
    let subtitle: String
    let messageBody: String?
    let messageTitle: String?
    let buttonText: ButtonText?
    let target: String?
    
    struct ButtonText: Codable {
        let cta: String
    }
}

// MARK: - Tesla Task
struct TeslaTask: Codable {
    let id: String
    let complete: Bool
    let enabled: Bool
    let required: Bool
    let order: Int
    let card: TeslaTaskCard?
    
    // Allow for dynamic properties
    private var additionalProperties: [String: AnyCodableValue] = [:]
    
    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, complete, enabled, required, order, card
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        complete = try container.decode(Bool.self, forKey: .complete)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        required = try container.decode(Bool.self, forKey: .required)
        order = try container.decode(Int.self, forKey: .order)
        card = try container.decodeIfPresent(TeslaTaskCard.self, forKey: .card)
        
        // Decode any additional properties
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        for key in dynamicContainer.allKeys {
            let codingKeyStrings = CodingKeys.allCases.map { $0.stringValue }
            if !codingKeyStrings.contains(key.stringValue) {
                if let value = try? dynamicContainer.decode(AnyCodableValue.self, forKey: key) {
                    additionalProperties[key.stringValue] = value
                }
            }
        }
    }
}

// MARK: - Order Details
struct OrderDetails: Codable {
    let tasks: [String: AnyCodableValue]
    
    init(tasks: [String: AnyCodableValue]) {
        self.tasks = tasks
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodableValue].self)
        
        // Try to extract the nested "tasks" key
        if let tasksValue = dict["tasks"],
           let tasksDict = tasksValue.value as? [String: Any] {
            // Convert [String: Any] to [String: AnyCodableValue]
            var convertedTasks: [String: AnyCodableValue] = [:]
            for (key, value) in tasksDict {
                convertedTasks[key] = AnyCodableValue(value)
            }
            tasks = convertedTasks
        } else {
            // Fallback: use the whole dict if no nested tasks
            tasks = dict
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        for (key, value) in tasks {
            if let codingKey = DynamicCodingKeys(stringValue: key) {
                try container.encode(value, forKey: codingKey)
            }
        }
    }
}

// MARK: - Combined Order
struct CombinedOrder: Codable, Identifiable {
    let order: TeslaOrder
    let details: OrderDetails
    
    var id: String {
        order.referenceNumber
    }
}

// MARK: - Historical Snapshot
struct HistoricalSnapshot: Codable {
    let timestamp: Int
    let data: CombinedOrder
}

// MARK: - Order Diff
struct OrderDiff: Codable {
    var changes: [String: DiffValue]
    
    struct DiffValue: Codable {
        let old: AnyCodableValue
        let new: AnyCodableValue
    }
}

// MARK: - Helper Types for Dynamic Coding

struct AnyCodableValue: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodableValue].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodableValue].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodableValue($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodableValue($0) })
        default:
            try container.encodeNil()
        }
    }
}

extension AnyCodableValue: Equatable {
    static func == (lhs: AnyCodableValue, rhs: AnyCodableValue) -> Bool {
        return String(describing: lhs.value) == String(describing: rhs.value)
    }
}

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

