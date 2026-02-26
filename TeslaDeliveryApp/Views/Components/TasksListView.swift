import SwiftUI

struct TasksListView: View {
    let tasks: [String: AnyCodableValue]
    let orderReferenceNumber: String
    
    // Define the order of tasks to display
    let orderedKeys = [
        "order",
        "registration",
        "tradeIn",
        "financing",
        "insurance",
        "finalPayment",
        "deliveryAcceptance",
        "agreements",
        "scheduling"
    ]
    
    var visibleTasks: [TeslaTaskViewModel] {
        var result: [TeslaTaskViewModel] = []
        
        for key in orderedKeys {
            if let value = tasks[key]?.value,
               let dict = value as? [String: Any] {
                result.append(TeslaTaskViewModel(key: key, data: dict, orderReferenceNumber: orderReferenceNumber))
            }
        }
        
        // Add any remaining tasks that aren't in the ordered list
        let remainingKeys = tasks.keys.filter { !orderedKeys.contains($0) }.sorted()
        for key in remainingKeys {
            if let value = tasks[key]?.value,
               let dict = value as? [String: Any] {
                result.append(TeslaTaskViewModel(key: key, data: dict, orderReferenceNumber: orderReferenceNumber))
            }
        }
        
        // Determine active task (first incomplete task)
        if let firstIncompleteIndex = result.firstIndex(where: { !$0.isComplete }) {
            result[firstIncompleteIndex].isActive = true
        }
        
        return result
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if visibleTasks.isEmpty {
                    Text("No tasks available")
                        .foregroundColor(.adaptiveSecondary)
                        .padding()
                } else {
                    ForEach(visibleTasks, id: \.key) { task in
                        TeslaTaskRow(task: task)
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Task View Model
struct TeslaTaskViewModel {
    let key: String
    let data: [String: Any]
    let orderReferenceNumber: String
    var isActive: Bool = false // Set by parent view
    
    var isComplete: Bool {
        if let complete = data["complete"] as? Bool {
            return complete
        }
        if let status = data["status"] as? String {
            return status.lowercased() == "complete"
        }
        return false
    }
    
    var statusColor: Color {
        if isComplete { return .green }
        if isActive { return .blue }
        return .gray
    }
    
    var title: String {
        switch key {
        case "order": return "Order Placed"
        case "registration": return "Registration"
        case "tradeIn": return "Trade-In"
        case "financing": return "Financing"
        case "insurance": return "Insurance"
        case "finalPayment": return "Final Payment"
        case "deliveryAcceptance": return "Delivery Acceptance"
        case "agreements": return "Review Agreements"
        case "scheduling": return "Delivery Appointment"
        case "accessories": return "Accessories"
        default: return key.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }
    
    var subtitle: String {
        if isComplete {
            switch key {
            case "registration":
                return "Registration details confirmed"
            case "tradeIn":
                return "No Trade-In"
            case "financing":
                return "Loan application submitted"
            case "insurance":
                return "Insurance uploaded"
            default:
                if let status = data["appointmentStatusName"] as? String, !status.isEmpty {
                   return status // e.g. "Appointment Scheduled"
                }
                return "Complete"
            }
        } else {
            switch key {
            case "registration":
                return "Please provide your registration details"
            case "tradeIn":
                return "Select if you have a vehicle to trade in"
            case "financing":
                return "Review financing terms and submit application"
            case "insurance":
                return "Upload proof of insurance"
            case "finalPayment":
                return "Pay the remaining balance prior to delivery"
            case "scheduling":
                if let status = data["appointmentStatusName"] as? String, !status.isEmpty {
                    return status
                }
                return "Schedule your delivery now"
            default:
                return "Action required"
            }
        }
    }
    
    var actionText: String? {
        if !isComplete {
            if let card = data["card"] as? [String: Any],
               let button = card["buttonText"] as? [String: Any],
               let cta = button["cta"] as? String {
                return cta
            }
            // Defaults based on type
            switch key {
            case "registration", "tradeIn", "financing", "insurance": return "Start"
            case "finalPayment": return "Pay"
            case "scheduling": return "Schedule"
            default: return "View"
            }
        }
        return isComplete ? "View" : nil
    }
    
    var actionUrl: URL? {
        // 1. Try to find explicit URL in the data
        if let urlString = data["url"] as? String, let url = URL(string: urlString) {
            return url
        }
        if let urlString = data["selfSchedulingUrl"] as? String, let url = URL(string: urlString) {
            return url
        }
        if let card = data["card"] as? [String: Any],
           let button = card["buttonText"] as? [String: Any],
           let link = button["link"] as? String,
           let url = URL(string: link) {
            return url
        }
        
        // 2. Fallback to Tesla Account URL with appropriate context
        // This usually redirects to the right place if logged in
        var baseUrl = "https://www.tesla.com/teslaaccount/profile?rn=\(orderReferenceNumber)"
        
        // Add anchor if possible (this is a guess, but better than nothing)
        switch key {
        case "payment", "finalPayment": baseUrl += "#payment"
        case "documents", "agreements": baseUrl += "#documents"
        default: break
        }
        
        return URL(string: baseUrl)
    }
}

// MARK: - Task Row View
struct TeslaTaskRow: View {
    let task: TeslaTaskViewModel
    @Environment(\.openURL) var openURL
    
    var body: some View {
        Button(action: {
            if let url = task.actionUrl {
                openURL(url)
            }
        }) {
            HStack(alignment: .top, spacing: 16) {
                // Status Icon
                ZStack {
                    if task.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 24))
                    } else {
                        Circle()
                            .stroke(task.statusColor, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if task.isActive {
                            Circle()
                                .fill(task.statusColor.opacity(0.1))
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(task.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.adaptiveText)
                    
                    // Subtitle
                    Text(task.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Action Button Indicator
                // Only show for incomplete tasks or if we explicitly want to allow viewing completed ones
                if let action = task.actionText {
                    HStack(spacing: 4) {
                        Text(action)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Needed to avoid default list row highlight effect
    }
}

#Preview {
    TasksListView(tasks: [:], orderReferenceNumber: "RN123")
}
