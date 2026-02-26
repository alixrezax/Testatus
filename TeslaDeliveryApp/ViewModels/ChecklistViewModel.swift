import Foundation
import Combine

@MainActor
class ChecklistViewModel: ObservableObject {
    @Published var sections: [ChecklistSectionData] = []
    
    private let storage = StorageManager.shared
    private let orderReference: String
    
    struct ChecklistSectionData: Identifiable {
        let id = UUID()
        let title: String
        var items: [ChecklistItem]
    }
    
    init(orderReference: String) {
        self.orderReference = orderReference
        loadChecklist()
    }
    
    func loadChecklist() {
        // Load saved progress or start fresh
        if let savedItems = storage.loadChecklistProgress(for: orderReference) {
            // Merge saved items with default sections
            sections = DeliveryChecklist.sections.map { section in
                let updatedItems = section.items.map { item in
                    if let savedItem = savedItems.first(where: { $0.id == item.id }) {
                        return savedItem
                    }
                    return item
                }
                return ChecklistSectionData(title: section.title, items: updatedItems)
            }
        } else {
            // Use defaults
            sections = DeliveryChecklist.sections.map { section in
                ChecklistSectionData(title: section.title, items: section.items)
            }
        }
    }
    
    func toggleItem(sectionIndex: Int, itemIndex: Int) {
        sections[sectionIndex].items[itemIndex].isCompleted.toggle()
        saveChecklist()
    }
    
    func saveChecklist() {
        let allItems = sections.flatMap { $0.items }
        storage.saveChecklistProgress(allItems, for: orderReference)
    }
    
    var completionPercentage: Double {
        let allItems = sections.flatMap { $0.items }
        let completedCount = allItems.filter { $0.isCompleted }.count
        return allItems.isEmpty ? 0 : Double(completedCount) / Double(allItems.count) * 100
    }
}
