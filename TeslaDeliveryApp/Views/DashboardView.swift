import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.orders.isEmpty && !viewModel.isLoading {
                            EmptyStateView()
                        } else {
                            ForEach(viewModel.orders) { order in
                                OrderCardView(
                                    combinedOrder: order,
                                    diff: viewModel.diffs[order.id] ?? [:]
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.fetchOrders(isManualRefresh: true)
                }
                
                // Toast overlay
                if let message = viewModel.toastMessage {
                    VStack {
                        Spacer()
                        ToastView(message: message, type: viewModel.toastType)
                            .padding()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation {
                                        viewModel.hideToast()
                                    }
                                }
                            }
                    }
                }
                
                // Loading overlay
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    LoadingView()
                }
            }
            .navigationTitle("Delivery Status")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await viewModel.fetchOrders(isManualRefresh: true)
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                                .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                        }
                        
                        Button(action: {
                            showingLogoutAlert = true
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    viewModel.logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Orders Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("We couldn't find any orders associated with your account.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 100)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "E82127")))
                
                Text("Fetching your order data...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(hex: "171A20"))
            .cornerRadius(16)
        }
    }
}

struct ToastView: View {
    let message: String
    let type: AppViewModel.ToastType
    
    var backgroundColor: Color {
        switch type {
        case .success:
            return Color.green.opacity(0.9)
        case .info:
            return Color.blue.opacity(0.9)
        case .error:
            return Color.red.opacity(0.9)
        }
    }
    
    var iconName: String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
            
            Text(message)
                .font(.system(size: 15, weight: .medium))
            
            Spacer()
        }
        .foregroundColor(.white)
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppViewModel())
}
