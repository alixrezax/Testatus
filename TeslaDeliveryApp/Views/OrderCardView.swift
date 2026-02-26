import SwiftUI

struct OrderCardView: View {
    let combinedOrder: CombinedOrder
    let diff: [String: OrderDiff.DiffValue]
    
    @State private var selectedTab: OrderTab = .details
    @State private var isExpanded = false
    
    enum OrderTab {
        case details, tasks, checklist, json
    }
    
    var hasChanges: Bool {
        !diff.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            OrderHeaderView(order: combinedOrder.order, hasChanges: hasChanges)
            
            // Tab selector
            TabSelectorView(selectedTab: $selectedTab)
            
            // Content based on selected tab
            Group {
                switch selectedTab {
                case .details:
                    OrderDetailsView(combinedOrder: combinedOrder, diff: diff, isExpanded: $isExpanded)
                case .tasks:
                    TasksListView(tasks: combinedOrder.details.tasks, orderReferenceNumber: combinedOrder.order.referenceNumber)
                case .checklist:
                    DeliveryChecklistView(orderReference: combinedOrder.order.referenceNumber)
                case .json:
                    JSONViewerView(data: combinedOrder)
                }
            }
        }
        .background(Color.adaptiveCardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct OrderHeaderView: View {
    let order: TeslaOrder
    let hasChanges: Bool
    
    var modelCode: String {
        order.modelCode.normalizedTeslaModelCode()
    }
    
    var statusColor: Color {
        let status = order.orderStatus.lowercased()
        if status.contains("delivered") || status.contains("complete") {
            return .green
        } else if status.contains("progress") || status.contains("pending") {
            return .orange
        } else if status.contains("cancel") {
            return .red
        } else if status.contains("book") {
            return .blue
        }
        return .gray
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Model \(modelCode)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.adaptiveText)
                        
                        if order.isUsed == true {
                            Text("USED")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(order.referenceNumber)
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondary)
                        .monospaced()
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if hasChanges {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .foregroundColor(.orange)
                    }
                    
                    Text(order.orderStatus)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            // Car image carousel
            if let carImageURLs = getCarImageURLs(), !carImageURLs.isEmpty {
                TabView {
                    ForEach(carImageURLs, id: \.self) { url in
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .padding(.bottom, 35) // Make space for page indicator
                                    .padding(.horizontal)
                            case .failure:
                                Image(systemName: "car.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 250) // Increased height to accommodate padding
            } else {
                // Fallback for no images or static image
                Image(systemName: "car.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .frame(height: 200)
            }
        }
        .padding()
    }
    
    func getCarImageURLs() -> [URL]? {
        // Try compositor first
        if let apiCode = order.modelCode.teslaModelAPICode(),
           let options = order.mktOptions {
            let formattedOptions = options.split(separator: ",").map { "$\($0.trimmingCharacters(in: .whitespaces))" }.joined(separator: ",")
            let views = ["STUD_3QTR", "STUD_SIDE", "STUD_REAR", "STUD_SEAT", "INTERIOR_ROW2", "RIMCLOSEUP"]
            
            var urls: [URL] = []
            for view in views {
                var urlString = "\(APIEndpoint.compositorBaseURL)?context=design_studio_2&bkba_opt=1&model=\(apiCode)&options=\(formattedOptions)&view=\(view)&size=1024"
                
                // Apply crop only to exterior/interior views that need trimming. 
                // RIMCLOSEUP looks too zoomed with the standard crop, so we skip it (or use a different one).
                // For now, removing crop for RIMCLOSEUP to show more context (effectively zooming out).
                if view != "RIMCLOSEUP" {
                    urlString += "&crop=1150,647,390,180"
                }
                
                if let url = URL(string: urlString) {
                    urls.append(url)
                }
            }
            return urls.isEmpty ? nil : urls
        }
        
        // Fallback to static image (return as single item array)
        if let fallbackURL = FallbackCarImages.urls[modelCode], let url = URL(string: fallbackURL) {
            return [url]
        }
        
        return nil
    }
}

struct TabSelectorView: View {
    @Binding var selectedTab: OrderCardView.OrderTab
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "Details", icon: "car.fill", tab: .details, selectedTab: $selectedTab)
            TabButton(title: "Tasks", icon: "checklist", tab: .tasks, selectedTab: $selectedTab)
            TabButton(title: "Checklist", icon: "list.bullet.clipboard", tab: .checklist, selectedTab: $selectedTab)
            TabButton(title: "JSON", icon: "doc.text", tab: .json, selectedTab: $selectedTab)
        }
        .background(Color.gray.opacity(0.1))
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let tab: OrderCardView.OrderTab
    @Binding var selectedTab: OrderCardView.OrderTab
    
    var isSelected: Bool {
        selectedTab == tab
    }
    
    var body: some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? Color(hex: "E82127") : .adaptiveText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: "E82127").opacity(0.1) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color(hex: "E82127") : Color.clear)
                    .frame(height: 3),
                alignment: .bottom
            )
        }
    }
}

#Preview {
    OrderCardView(
        combinedOrder: CombinedOrder(
            order: TeslaOrder(
                referenceNumber: "RN123456",
                orderStatus: "Booked",
                modelCode: "m3",
                vin: "5YJ3E1EA1JF000001",
                isB2b: false,
                ownerCompanyName: nil,
                isUsed: false,
                mktOptions: "WHITE,INPB,SLR1,W40B"
            ),
            details: OrderDetails(tasks: [:])
        ),
        diff: [:]
    )
    .padding()
}
