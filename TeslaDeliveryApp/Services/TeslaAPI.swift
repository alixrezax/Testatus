import Foundation
import AuthenticationServices
import Combine

// MARK: - Token Expired Error
enum TeslaAPIError: Error, LocalizedError {
    case tokenExpired
    case authenticationFailed(String)
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case missingCodeVerifier
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .tokenExpired:
            return "Access token has expired"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .missingCodeVerifier:
            return "Code verifier not found"
        case .invalidURL:
            return "Invalid URL"
        }
    }
}

// MARK: - Tesla API Service
@MainActor
class TeslaAPI: ObservableObject {
    static let shared = TeslaAPI()
    
    private init() {}
    
    // MARK: - Authentication
    
    func handleTeslaLogin() async throws -> (codeVerifier: String, authState: String) {
        let state = Data(UUID().uuidString.utf8).base64EncodedString()
        let codeVerifier = PKCEHelper.generateCodeVerifier()
        let codeChallenge = PKCEHelper.generateCodeChallenge(from: codeVerifier)
        
        // Store in UserDefaults temporarily
        UserDefaults.standard.set(codeVerifier, forKey: StorageKey.codeVerifier)
        UserDefaults.standard.set(state, forKey: StorageKey.authState)
        
        var components = URLComponents(string: APIEndpoint.authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: APIEndpoint.clientID),
            URLQueryItem(name: "redirect_uri", value: APIEndpoint.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: APIEndpoint.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: APIEndpoint.codeChallengeMethod)
        ]
        
        guard let authURL = components.url else {
            throw TeslaAPIError.invalidURL
        }
        
        // In SwiftUI, this will be handled by the view using ASWebAuthenticationSession
        return (codeVerifier: codeVerifier, authState: state)
    }
    
    func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> TeslaTokens {
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "codeVerifier": codeVerifier
        ]
        
        guard let url = URL(string: APIEndpoint.proxyAPIURL) else {
            throw TeslaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeslaAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorDict["error_description"] ?? errorDict["error"] {
                throw TeslaAPIError.authenticationFailed(errorMessage)
            }
            throw TeslaAPIError.authenticationFailed("Status code: \(httpResponse.statusCode)")
        }
        
        // Debug logging
        print("📱 Token Exchange Response Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📱 Token Exchange Response Body: \(responseString)")
        }
        
        do {
            return try JSONDecoder().decode(TeslaTokens.self, from: data)
        } catch {
            print("❌ Decoding Error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ Missing key: \(key.stringValue), context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch for type: \(type), context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("❌ Value not found for type: \(type), context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("❌ Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("❌ Unknown decoding error")
                }
            }
            throw TeslaAPIError.decodingError(error)
        }
    }
    
    func refreshAccessToken(refreshToken: String) async throws -> TeslaTokens {
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        guard let url = URL(string: APIEndpoint.proxyAPIURL) else {
            throw TeslaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeslaAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
           if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorDict["error_description"] ?? errorDict["error"] {
                throw TeslaAPIError.authenticationFailed(errorMessage)
            }
            throw TeslaAPIError.authenticationFailed("Status code: \(httpResponse.statusCode)")
        }
        
        do {
            return try JSONDecoder().decode(TeslaTokens.self, from: data)
        } catch {
            throw TeslaAPIError.decodingError(error)
        }
    }
    
    // MARK: - Data Fetching
    
    private func proxyAPIRequest(targetURL: String, accessToken: String) async throws -> Data {
        let body: [String: String] = [
            "action": "proxy",
            "targetUrl": targetURL,
            "accessToken": accessToken
        ]
        
        guard let url = URL(string: APIEndpoint.proxyAPIURL) else {
            throw TeslaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeslaAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw TeslaAPIError.tokenExpired
        }
        
        if httpResponse.statusCode != 200 {
            if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorDict["error_description"] ?? errorDict["error"] {
                throw TeslaAPIError.networkError(NSError(domain: "TeslaAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            }
            throw TeslaAPIError.invalidResponse
        }
        
        return data
    }
    
    func getOrders(accessToken: String) async throws -> [TeslaOrder] {
        let data = try await proxyAPIRequest(targetURL: APIEndpoint.ordersAPIURL, accessToken: accessToken)
        
        // Parse the response which has a "response" wrapper
        struct OrdersResponse: Codable {
            let response: [TeslaOrder]
        }
        
        do {
            let response = try JSONDecoder().decode(OrdersResponse.self, from: data)
            return response.response
        } catch {
            throw TeslaAPIError.decodingError(error)
        }
    }
    
    func getOrderDetails(orderId: String, accessToken: String) async throws -> OrderDetails {
        let url = APIEndpoint.orderDetailsAPITemplate.replacingOccurrences(of: "{ORDER_ID}", with: orderId)
        let data = try await proxyAPIRequest(targetURL: url, accessToken: accessToken)
        
        do {
            return try JSONDecoder().decode(OrderDetails.self, from: data)
        } catch {
            throw TeslaAPIError.decodingError(error)
        }
    }
    
    func getAllOrderData(accessToken: String) async throws -> [CombinedOrder] {
        let basicOrders = try await getOrders(accessToken: accessToken)
        
        if basicOrders.isEmpty {
            return []
        }
        
        // Fetch details for all orders concurrently
        return try await withThrowingTaskGroup(of: CombinedOrder.self) { group in
            for order in basicOrders {
                group.addTask {
                    let details = try await self.getOrderDetails(orderId: order.referenceNumber, accessToken: accessToken)
                    return CombinedOrder(order: order, details: details)
                }
            }
            
            var combinedOrders: [CombinedOrder] = []
            for try await combined in group {
                combinedOrders.append(combined)
            }
            return combinedOrders
        }
    }
}
