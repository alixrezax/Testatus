import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showManualInput = false
    @State private var callbackURL = ""
    @State private var authURL = ""
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "171A20"), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    Spacer().frame(height: 60)
                    
                    // Tesla logo
                    Image(systemName: "bolt.car.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color(hex: "E82127"))
                    
                    VStack(spacing: 16) {
                        Text("Tesla Delivery")
                            .font(.system(size: 36, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        
                        Text("Track your order status")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer().frame(height: 20)
                    
                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    if !showManualInput {
                        // Auto login instructions
                        VStack(spacing: 20) {
                            Text("Login Instructions")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                InstructionRow(number: "1", text: "Tap 'Start Login' below")
                                InstructionRow(number: "2", text: "Login with your Tesla account")
                                InstructionRow(number: "3", text: "After login, you'll see 'Page Not Found'")
                                InstructionRow(number: "4", text: "Copy the page URL (Share → Copy)")
                                InstructionRow(number: "5", text: "Tap 'I have the link' and paste URL")
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Generate auth URL and open Safari button
                            Button(action: {
                                Task {
                                    await generateAndOpenAuthURL()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    if viewModel.isAuthenticating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "person.badge.key.fill")
                                            .font(.system(size: 20))
                                    }
                                    Text("Start Login")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "E82127"))
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.isAuthenticating)
                            .padding(.horizontal, 40)
                            
                            // I have the link button
                            if !authURL.isEmpty {
                                Button(action: {
                                    showManualInput = true
                                }) {
                                    Text("I have the link ✓")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "E82127"))
                                        .padding(.vertical, 12)
                                }
                            }
                        }
                    } else {
                        // Manual URL input
                        VStack(spacing: 20) {
                            Text("Paste callback URL")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("The URL should start with:\nhttps://auth.tesla.com/void/callback?code=...")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            TextField("", text: $callbackURL, prompt: Text("Paste URL here...").foregroundColor(.gray))
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                Task {
                                    await handleManualURL()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    if viewModel.isAuthenticating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                    }
                                    Text("Confirm & Login")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(callbackURL.isEmpty ? Color.gray : Color(hex: "E82127"))
                                .cornerRadius(12)
                            }
                            .disabled(callbackURL.isEmpty || viewModel.isAuthenticating)
                            .padding(.horizontal, 40)
                            
                            Button(action: {
                                showManualInput = false
                                callbackURL = ""
                            }) {
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    func generateAndOpenAuthURL() async {
        do {
            // Check if we already have state/verifier stored
            var codeVerifier: String
            var authState: String
            
            if let existingVerifier = viewModel.storage.loadCodeVerifier(),
               let existingState = viewModel.storage.loadAuthState() {
                // Reuse existing state
                codeVerifier = existingVerifier
                authState = existingState
            } else {
                // Generate new ones
                let (newVerifier, newState) = try await viewModel.api.handleTeslaLogin()
                viewModel.storage.saveCodeVerifier(newVerifier)
                viewModel.storage.saveAuthState(newState)
                codeVerifier = newVerifier
                authState = newState
            }
            
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
            
            authURL = components.url?.absoluteString ?? ""
            
            // Automatically open Safari
            if let url = URL(string: authURL) {
                await UIApplication.shared.open(url)
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
    
    func handleManualURL() async {
        // Decode URL if it's percent-encoded
        let decodedURL = callbackURL.removingPercentEncoding ?? callbackURL
        
        guard let url = URL(string: decodedURL) else {
            viewModel.errorMessage = "Invalid URL"
            return
        }
        
        await viewModel.handleAuthCallback(url: url)
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color(hex: "E82127"))
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Adaptive text color - black in light mode, white in dark mode
    static var adaptiveText: Color {
        Color(UIColor.label)
    }
    
    /// Adaptive secondary text color - gray in both modes
    static var adaptiveSecondary: Color {
        Color(UIColor.secondaryLabel)
    }
    
    /// Adaptive background color for cards/cells
    static var adaptiveCardBackground: Color {
        Color(UIColor.secondarySystemGroupedBackground)
    }
}

#Preview {
    LoginView()
        .environmentObject(AppViewModel())
}
