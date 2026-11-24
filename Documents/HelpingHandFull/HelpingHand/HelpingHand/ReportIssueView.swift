import SwiftUI
import UIKit

// MARK: - Supabase config
enum SupabaseConfig {
    static let url = URL(string: "https://kwhqxukkogtzrrouirpp.supabase.co")!
    // Publishable key: safe to ship in the app because Row Level Security limits what it can do.
    // NEVER put the secret key (sb_secret_...) here.
    static let publishableKey = "sb_publishable_hVr2cTwT1LhotiLG_ZvIYA_JwymR7ov"
}

// MARK: - Report model
enum ReportCategory: String, Codable, CaseIterable, Identifiable {
    case crisisInfo = "crisis_info"
    case dropOffInfo = "dropoff_info"
    case appBug = "app_bug"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .crisisInfo: return "Crisis info is wrong or outdated"
        case .dropOffInfo: return "Drop-off point info is wrong"
        case .appBug: return "Something in the app isn't working"
        case .other: return "Something else"
        }
    }
}

enum ReportTargetType: String, Codable {
    case crisis, dropoff, app
}

/// What the report is about. Pass one in to pre-fill the form from a crisis or drop-off screen.
struct ReportTarget {
    let type: ReportTargetType
    let id: String?
    let name: String?

    static let app = ReportTarget(type: .app, id: nil, name: nil)
}

private struct ReportPayload: Encodable {
    let category: String
    let targetType: String
    let targetId: String?
    let targetName: String?
    let message: String
    let contactEmail: String?
    let appVersion: String?
    let device: String
}

// MARK: - Service
enum ReportService {
    struct ServerError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @MainActor
    static func submit(category: ReportCategory, target: ReportTarget, message: String, contactEmail: String?) async throws {
        let payload = ReportPayload(
            category: category.rawValue,
            targetType: target.type.rawValue,
            targetId: target.id,
            targetName: target.name,
            message: message,
            contactEmail: contactEmail,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            device: "\(UIDevice.current.model) iOS \(UIDevice.current.systemVersion)"
        )

        // Insert straight into the `reports` table via Supabase's Data API.
        var request = URLRequest(url: SupabaseConfig.url.appendingPathComponent("rest/v1/reports"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        // Reports are write-only for the app, so don't ask for the row back
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            struct SupabaseError: Decodable { let message: String? }
            let detail = (try? JSONDecoder().decode(SupabaseError.self, from: data))?.message
            #if DEBUG
            print("Report submit failed:", detail ?? String(data: data, encoding: .utf8) ?? "unknown")
            #endif
            if detail?.contains("contact_email") == true {
                throw ServerError(message: "That email address doesn't look right.")
            }
            throw ServerError(message: "The report couldn't be sent. Please try again.")
        }
    }
}

// MARK: - View
struct ReportIssueView: View {
    var target: ReportTarget = .app

    @Environment(\.dismiss) private var dismiss
    @State private var category: ReportCategory
    @State private var message = ""
    @State private var contactEmail = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var submitted = false

    init(target: ReportTarget = .app) {
        self.target = target
        switch target.type {
        case .crisis: _category = State(initialValue: .crisisInfo)
        case .dropoff: _category = State(initialValue: .dropOffInfo)
        case .app: _category = State(initialValue: .appBug)
        }
    }

    private var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSubmit: Bool { trimmedMessage.count >= 5 && !isSubmitting }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    thankYou
                } else {
                    form
                }
            }
            .navigationTitle("Report an Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(submitted ? "Done" : "Cancel") { dismiss() }
                        .foregroundStyle(Color.primary)
                }
                if !submitted {
                    ToolbarItem(placement: .topBarTrailing) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Button("Send") { Task { await submit() } }
                                .fontWeight(.semibold)
                                .disabled(!canSubmit)
                        }
                    }
                }
            }
        }
    }

    private var form: some View {
        Form {
            if let name = target.name {
                Section("Reporting about") {
                    Label(name, systemImage: target.type == .crisis ? "exclamationmark.triangle" : "shippingbox")
                }
            }

            Section("What's the problem?") {
                Picker("Category", selection: $category) {
                    ForEach(ReportCategory.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                TextEditor(text: $message)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Tell us what's wrong. For example: this drop-off point closed last week.")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: message) { _, newValue in
                        if newValue.count > 2000 { message = String(newValue.prefix(2000)) }
                    }
            } header: {
                Text("Details")
            } footer: {
                Text("\(message.count)/2000")
            }

            Section {
                TextField("Email (optional)", text: $contactEmail)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Only if you'd like us to follow up with you.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var thankYou: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(red: 0.85, green: 0.42, blue: 0.32))
            Text("Thanks for letting us know")
                .font(.title3.weight(.semibold))
            Text("Reports like yours keep crisis and drop-off information accurate for everyone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let email = contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await ReportService.submit(
                category: category,
                target: target,
                message: trimmedMessage,
                contactEmail: email.isEmpty ? nil : email
            )
            withAnimation { submitted = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ReportIssueView(target: ReportTarget(type: .dropoff, id: "dp-1", name: "Red Cross Logistics Center"))
}
