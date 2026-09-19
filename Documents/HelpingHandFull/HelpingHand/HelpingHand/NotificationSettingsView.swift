import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Using the models defined in AppModels.swift
    @State private var selectedFrequency: AlertFrequency = .dailyDigest
    @State private var quietHoursEnabled = false
    @State private var digestTime = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Alert Cadence", selection: $selectedFrequency) {
                        Text("Immediate").tag(AlertFrequency.immediate)
                        Text("Daily Digest").tag(AlertFrequency.dailyDigest)
                        Text("Weekly Summary").tag(AlertFrequency.weeklySummary)
                    }
                    .pickerStyle(.inline)
                    
                    if selectedFrequency == .dailyDigest {
                        DatePicker("Digest Delivery Time", selection: $digestTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Update Frequency")
                } footer: {
                    Text("Immediate alerts notify you instantly of severe status changes. Daily digests compile all verified needs into a single daily summary.")
                }
                
                Section {
                    Toggle("Enable Quiet Hours", isOn: $quietHoursEnabled)
                        .tint(Color(red: 0.85, green: 0.42, blue: 0.32)) // Soft coral accent
                } footer: {
                    Text("Silences all incoming alerts during specified nighttime hours, automatically holding updates until morning.")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Save logic to backend would go here
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                }
            }
        }
    }
}
