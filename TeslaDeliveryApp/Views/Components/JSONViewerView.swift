import SwiftUI

struct JSONViewerView: View {
    let data: CombinedOrder
    
    @State private var jsonString: String = ""
    
    var body: some View {
        ScrollView {
            Text(jsonString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.adaptiveText)
                .padding()
                .textSelection(.enabled)
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            formatJSON()
        }
    }
    
    private func formatJSON() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(data)
            jsonString = String(data: jsonData, encoding: .utf8) ?? "Failed to format JSON"
        } catch {
            jsonString = "Error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    JSONViewerView(
        data: CombinedOrder(
            order: TeslaOrder(
                referenceNumber: "RN123456",
                orderStatus: "Booked",
                modelCode: "m3",
                vin: "5YJ3E1EA1JF000001",
                isB2b: false,
                ownerCompanyName: nil,
                isUsed: false,
                mktOptions: nil
            ),
            details: OrderDetails(tasks: [:])
        )
    )
}
