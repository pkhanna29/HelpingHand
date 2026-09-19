import Foundation

// MARK: - In-Kind Donation Logistics
// Modeled around the structural matching needs of physical goods
struct PhysicalAidRequirement: Identifiable, Codable {
    let id: String
    let targetRegionID: String
    let itemCategory: String // e.g., "Medical", "Clothing", "Water Filters"
    let urgencyLevel: Int // 1 to 5 scale
    let verifiedNGO: String
    let dropOffLocations: [DropOffPoint]
}

struct DropOffPoint: Identifiable, Codable {
    let id: String
    let facilityName: String
    let latitude: Double
    let longitude: Double
    let acceptedItems: [String]
    let operatingHours: String
}

// MARK: - User Preferences & Notifications
struct UserProfile: Identifiable, Codable {
    let id: String
    var pinnedRegionIDs: [String]
    var notificationSettings: NotificationPreferences
}

struct NotificationPreferences: Codable {
    var frequency: AlertFrequency
    var digestTime: String // Format "HH:mm" for daily digest schedules
    var quietHoursEnabled: Bool
}

enum AlertFrequency: String, Codable {
    case immediate = "immediate"
    case dailyDigest = "daily_digest"
    case weeklySummary = "weekly_summary"
}
