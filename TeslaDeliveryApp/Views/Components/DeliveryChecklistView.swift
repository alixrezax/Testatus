import SwiftUI

struct DeliveryChecklistView: View {
    @StateObject private var viewModel: ChecklistViewModel
    
    init(orderReference: String) {
        _viewModel = StateObject(wrappedValue: ChecklistViewModel(orderReference: orderReference))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Progress header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completion: \(Int(viewModel.completionPercentage))%")
                        .font(.headline)
                        .foregroundColor(.adaptiveText)
                    
                    ProgressView(value: viewModel.completionPercentage, total: 100)
                        .tint(Color(hex: "E82127"))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Sections
                ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { sectionIndex, section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.adaptiveText)
                        
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { itemIndex, item in
                            ChecklistItemRow(
                                item: item,
                                onToggle: {
                                    viewModel.toggleItem(sectionIndex: sectionIndex, itemIndex: itemIndex)
                                }
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(item.isCompleted ? .green : .gray)
                
                Text(item.text)
                    .font(.body)
                    .foregroundColor(.adaptiveText)
                    .strikethrough(item.isCompleted)
                
                Spacer()
            }
            .padding(12)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    DeliveryChecklistView(orderReference: "RN123456")
}
