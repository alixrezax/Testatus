import Foundation
import SwiftUI
import AuthenticationServices
import Combine

@MainActor
class AppViewModel: ObservableObject {
    @Published var tokens: TeslaTokens?
    @Published var orders: [CombinedOrder] = []
    @Published var diffs: [String: [String: OrderDiff.DiffValue]] = [:]
    @Published var isLoading = false
    @Published var isAuthenticating = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published var toastType: ToastType = .info
    
    let api = TeslaAPI.shared
    let storage = StorageManager.shared
    
    enum ToastType {
        case success
        case info
        case error
    }
    
    init() {
        loadExistingSession()
    }
    
    // MARK: - Authentication
    
    func loadExistingSession() {
        isLoading = true
        
        Task {
            defer { isLoading = false }
            
            do {
                guard let storedTokens = try storage.loadTokensFromKeychain() else {
                    return
                }
                
                // Check if token is expired and refresh if needed
                if storedTokens.isExpired {
                    let newTokens = try await api.refreshAccessToken(refreshToken: storedTokens.refreshToken)
                    try storage.saveTokensToKeychain(newTokens)
                    self.tokens = newTokens
                } else {
                    self.tokens = storedTokens
                }
                
                // Auto-fetch orders
                await fetchOrders()
                
            } catch {
                print("Failed to load session: \(error.localizedDescription)")
                // Don't show error, just let user log in
            }
        }
    }
    
    func startAuthentication(presenter: ASWebAuthenticationPresentationContextProviding) async {
        isAuthenticating = true
        errorMessage = nil
        
        do {
            let (codeVerifier, authState) = try await api.handleTeslaLogin()
            storage.saveCodeVerifier(codeVerifier)
            storage.saveAuthState(authState)
            
            // Construct auth URL
            var components = URLComponents(string: APIEndpoint.authURL)!
            let codeChallenge = PKCEHelper.generateCodeChallenge(from: codeVerifier)
            
            components.queryItems = [
                URLQueryItem(name: "client_id", value: APIEndpoint.clientID),
                URLQueryItem(name: "redirect_uri", value: APIEndpoint.redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: APIEndpoint.scope),
                URLQueryItem(name: "state", value: authState),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: APIEndpoint.codeChallengeMethod)
            ]
            
            guard let authURL = components.url else {
                throw TeslaAPIError.invalidURL
            }
            
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "https"
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.isAuthenticating = false
                        if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                        }
                        return
                    }
                    
                    guard let callbackURL = callbackURL else {
                        self.isAuthenticating = false
                        self.errorMessage = "No callback URL received"
                        return
                    }
                    
                    await self.handleAuthCallback(url: callbackURL)
                }
            }
            
            session.presentationContextProvider = presenter
            session.prefersEphemeralWebBrowserSession = false
            
            if !session.start() {
                isAuthenticating = false
                errorMessage = "Failed to start authentication session"
            }
            
        } catch {
            isAuthenticating = false
            errorMessage = error.localizedDescription
        }
    }
    
    func handleAuthCallback(url: URL) async {
        defer { isAuthenticating = false }
        
        do {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                  let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
                errorMessage = "Invalid callback URL"
                return
            }
            
            guard let storedState = storage.loadAuthState(), state == storedState else {
                errorMessage = "State mismatch - authentication failed"
                return
            }
            
            guard let codeVerifier = storage.loadCodeVerifier() else {
                errorMessage = "Code verifier not found"
                return
            }
            
            let newTokens = try await api.exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
            try storage.saveTokensToKeychain(newTokens)
            
            // Clean up temporary storage
            storage.deleteCodeVerifier()
            storage.deleteAuthState()
            
            tokens = newTokens
            
            // Fetch orders
            await fetchOrders()
            
        } catch {
            errorMessage = "Failed to complete authentication: \(error.localizedDescription)"
        }
    }
    
    func logout() {
        storage.clearAllData()
        tokens = nil
        orders = []
        diffs = [:]
        errorMessage = nil
    }
    
    // MARK: - Data Fetching
    
    func fetchOrders(isManualRefresh: Bool = false) async {
        guard let tokens = tokens else { return }
        
        isLoading = true
        if isManualRefresh {
            toastMessage = nil
        }
        errorMessage = nil
        
        do {
            let newOrders = try await fetchWithRetry(accessToken: tokens.accessToken) {
                try await self.api.getAllOrderData(accessToken: $0)
            }
            
            var latestDiffs: [String: [String: OrderDiff.DiffValue]] = [:]
            
            for newOrder in newOrders {
                let reference = newOrder.order.referenceNumber
                let history = try storage.loadOrderHistory(for: reference)
                
                if let lastSnapshot = history.last {
                    let diff = DiffGenerator.compareObjects(lastSnapshot.data, newOrder)
                    
                    if !diff.isEmpty {
                        // Save new snapshot
                        let snapshot = HistoricalSnapshot(timestamp: Int(Date().timeIntervalSince1970), data: newOrder)
                        try storage.appendToOrderHistory(snapshot, for: reference)
                        latestDiffs[reference] = diff
                    }
                } else {
                    // First time seeing this order
                    let snapshot = HistoricalSnapshot(timestamp: Int(Date().timeIntervalSince1970), data: newOrder)
                    try storage.appendToOrderHistory(snapshot, for: reference)
                }
            }
            
            orders = newOrders
            diffs = latestDiffs
            
            if !latestDiffs.isEmpty {
                showToast("New changes detected!", type: .success)
            } else if isManualRefresh {
                showToast("No new changes found", type: .info)
            }
            
        } catch {
            errorMessage = "Failed to fetch orders: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func fetchWithRetry<T>(accessToken: String, request: (String) async throws -> T) async throws -> T {
        do {
            return try await request(accessToken)
        } catch TeslaAPIError.tokenExpired {
            // Try to refresh token
            guard let currentTokens = tokens else {
                throw TeslaAPIError.tokenExpired
            }
            
            let newTokens = try await api.refreshAccessToken(refreshToken: currentTokens.refreshToken)
            try storage.saveTokensToKeychain(newTokens)
            self.tokens = newTokens
            
            // Retry with new token
            return try await request(newTokens.accessToken)
        }
    }
    
    // MARK: - Toast
    
    func showToast(_ message: String, type: ToastType = .info) {
        toastMessage = message
        toastType = type
    }
    
    func hideToast() {
        toastMessage = nil
    }
}
