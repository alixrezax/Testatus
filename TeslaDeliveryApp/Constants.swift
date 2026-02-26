import Foundation

// MARK: - API URLs
enum APIEndpoint {
    static let clientID = "ownerapi"
    static let redirectURI = "https://auth.tesla.com/void/callback"
    static let authURL = "https://auth.tesla.com/oauth2/v3/authorize"
    static let tokenURL = "https://auth.tesla.com/oauth2/v3/token"
    static let scope = "openid email offline_access"
    static let codeChallengeMethod = "S256"
    static let appVersion = "9.99.9-9999"
    static let ordersAPIURL = "https://owner-api.teslamotors.com/api/1/users/orders"
    static let orderDetailsAPITemplate = "https://akamai-apigateway-vfx.tesla.com/tasks?deviceLanguage=en&deviceCountry=US&referenceNumber={ORDER_ID}&appVersion=\(appVersion)"
    static let proxyAPIURL = "https://tesla-delivery-277250840124.europe-west1.run.app/"
    static let compositorBaseURL = "https://static-assets.tesla.com/configurator/compositor"
}

// MARK: - Storage Keys
enum StorageKey {
    static let teslaTokens = "tesla-tokens"
    static let codeVerifier = "tesla-code-verifier"
    static let authState = "tesla-auth-state"
    static let orderHistoryPrefix = "tesla-order-history-"
    static let checklistPrefix = "tesla-checklist-"
    static let theme = "theme"
}

// MARK: - App Constants
enum AppConstants {
    static let maxHistoryEntries = 20
}

// MARK: - Fallback Car Images
enum FallbackCarImages {
    static let urls: [String: String] = [
        "S": "https://digitalassets.tesla.com/tesla-contents/image/upload/f_auto,q_auto/Mega-Menu-Vehicles-Model-S.png",
        "3": "https://digitalassets.tesla.com/tesla-contents/image/upload/f_auto,q_auto/Mega-Menu-Vehicles-Model-3-Performance-LHD.png",
        "X": "https://digitalassets.tesla.com/tesla-contents/image/upload/f_auto,q_auto/Mega-Menu-Vehicles-Model-X.png",
        "Y": "https://digitalassets.tesla.com/tesla-contents/image/upload/f_auto,q_auto/Mega-Menu-Vehicles-Model-Y-2-v2.png",
        "CYBERTRUCK": "https://digitalassets.tesla.com/tesla-contents/image/upload/f_auto,q_auto/Mega-Menu-Vehicles-Cybertruck-1x.png"
    ]
}

// MARK: - Delivery Checklist
struct ChecklistSection {
    let title: String
    let items: [ChecklistItem]
}

struct ChecklistItem: Identifiable, Codable {
    let id: String
    let text: String
    var isCompleted: Bool = false
}

enum DeliveryChecklist {
    static let sections: [ChecklistSection] = [
        ChecklistSection(
            title: "Pre-Delivery Tasks",
            items: [
                ChecklistItem(id: "payment", text: "Finalize payment or financing"),
                ChecklistItem(id: "insurance", text: "Arrange vehicle insurance"),
                ChecklistItem(id: "documents", text: "Review all final documents in your account"),
                ChecklistItem(id: "charging", text: "Install or prepare home charging solution"),
                ChecklistItem(id: "trade-in", text: "Prepare your trade-in vehicle (if applicable)")
            ]
        ),
        ChecklistSection(
            title: "Delivery Day Inspection",
            items: [
                ChecklistItem(id: "exterior", text: "Inspect exterior for paint defects or panel gaps"),
                ChecklistItem(id: "interior", text: "Inspect interior for scuffs, stains, or damage"),
                ChecklistItem(id: "wheels", text: "Check wheels and tires for scrapes or damage"),
                ChecklistItem(id: "glass", text: "Inspect all glass for chips or cracks"),
                ChecklistItem(id: "accessories", text: "Verify all accessories are present (charging cables, mats, etc.)"),
                ChecklistItem(id: "software", text: "Check infotainment screen and basic software functions"),
                ChecklistItem(id: "charging_test", text: "Confirm vehicle is charging correctly with provided cable")
            ]
        )
    ]
}

// MARK: - Diff Key Labels
enum DiffKeyLabels {
    static let labels: [String: String] = [
        "order.orderStatus": "Order Status",
        "order.vin": "VIN",
        "details.tasks.deliveryDetails.regData.reggieLicensePlate": "License Plate",
        "order.mktOptions": "Vehicle Options",
        "order.ownerCompanyName": "Company Name",
        "details.tasks.scheduling.deliveryWindowDisplay": "Delivery Window",
        "details.tasks.scheduling.apptDateTimeAddressStr": "Delivery Appointment",
        "details.tasks.finalPayment.data.etaToDeliveryCenter": "ETA to Delivery Center",
        "details.tasks.registration.orderDetails.vehicleRoutingLocation": "Vehicle Location",
        "details.tasks.scheduling.deliveryType": "Delivery Method",
        "details.tasks.scheduling.deliveryAddressTitle": "Delivery Center",
        "details.tasks.registration.orderDetails.vehicleOdometer": "Odometer",
        "details.tasks.registration.orderDetails.reservationDate": "Reservation Date",
        "details.tasks.registration.orderDetails.orderBookedDate": "Order Booked Date"
    ]
}

// MARK: - Color Palette
enum TeslaColors {
    static let red = "E82127"
    static let darkGray = "171A20"
    static let lightGray = "F4F4F4"
    static let mediumGray = "5C5E62"
}
