import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    @State private var showingExportSheet = false
    @State private var exportText = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletedAlert = false
    @State private var showingDeleteAllConfirmation = false
    @State private var showingDeletedAllAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Health Connection
                Section {
                    HStack {
                        Label("Apple Health", systemImage: "heart.fill")
                            .foregroundColor(.ptTeal)
                        Spacer()
                        Text(healthKitManager.isAuthorized ? "Connected" : "Not Connected")
                            .foregroundColor(healthKitManager.isAuthorized ? .green : .secondary)
                    }
                    
                    if !healthKitManager.isAuthorized {
                        Button("Connect Apple Health") {
                            HapticManager.medium()
                            healthKitManager.requestAuthorization()
                        }
                    }
                    
                    Button("Manage Permissions in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(.ptTeal)
                    
                    HStack {
                        Label("Apple Watch", systemImage: "applewatch")
                        Spacer()
                        Text(healthKitManager.isAppleWatchConnected ? "Detected" : "Not Detected")
                            .foregroundColor(healthKitManager.isAppleWatchConnected ? .green : .secondary)
                    }
                } header: {
                    Text("Health Data")
                } footer: {
                    Text("An Apple Watch is required for real-time stress detection and high-frequency heart rate monitoring.")
                }
                
                // MARK: - Notifications
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Activity Notifications", systemImage: "bell.fill")
                    }
                    .tint(.ptTeal)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get notified when significant activity changes are detected. Notifications are limited to once per hour.")
                }
                

                
                // MARK: - Data Export
                Section {
                    Button {
                        exportActivitiesJSON()
                    } label: {
                        Label("Export Activities (JSON)", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        exportActivitiesCSV()
                    } label: {
                        Label("Export Activities (CSV)", systemImage: "tablecells")
                    }
                    
                    Button {
                        exportBaselineData()
                    } label: {
                        Label("Export Baseline Data", systemImage: "chart.line.uptrend.xyaxis")
                    }
                } header: {
                    Text("Data Export")
                } footer: {
                    Text("Export your activity logs and physiological baselines for personal records or research.")
                }
                
                // MARK: - Data Management
                Section {
                    Button(role: .destructive) {
                        HapticManager.warning()
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Clear All Activity Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("This removes all logged activities. Body Battery history and baselines are preserved.")
                }
                
                // MARK: - Data Management — Delete All Data
                Section {
                    Button(role: .destructive) {
                        HapticManager.warning()
                        showingDeleteAllConfirmation = true
                    } label: {
                        Label("Delete All My Data", systemImage: "trash.fill")
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Permanently removes all body battery history, stress predictions, activity logs, baselines, and preferences. This cannot be undone.")
                }
                
                // MARK: - Legal
                Section {
                    Link(destination: URL(string: "https://ctt011.github.io/Capstone-Behavorial/")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    Link(destination: URL(string: "https://ctt011.github.io/Capstone-Behavorial/")!) {
                        Label("Terms of Use", systemImage: "doc.text.fill")
                    }
                } header: {
                    Text("Legal")
                }
                
                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ShareSheet(text: exportText)
            }
            .alert("Delete All Activities?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    HapticManager.error()
                    ActivityManager.shared.clearAllActivities()
                    showingDeletedAlert = true
                }
            } message: {
                Text("This will permanently remove all your logged activities. This action cannot be undone.")
            }
            .alert("Activities Deleted", isPresented: $showingDeletedAlert) {
                Button("OK") { }
            } message: {
                Text("All activity data has been cleared.")
            }
            .alert("Delete All Data?", isPresented: $showingDeleteAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    HapticManager.error()
                    deleteAllUserData()
                    showingDeletedAllAlert = true
                }
            } message: {
                Text("This will permanently erase ALL your data including body battery history, stress predictions, activity logs, baselines, and preferences. The app will reset to its initial state. This cannot be undone.")
            }
            .alert("All Data Deleted", isPresented: $showingDeletedAllAlert) {
                Button("OK") { }
            } message: {
                Text("All your data has been erased. The app has been reset.")
            }
        }
    }
    
    // MARK: - Export Helpers
    
    private func exportActivitiesJSON() {
        guard let json = ActivityManager.shared.exportActivitiesAsJSON() else {
            exportText = "No activities to export."
            showingExportSheet = true
            return
        }
        exportText = json
        showingExportSheet = true
    }
    
    private func exportActivitiesCSV() {
        let csv = ActivityManager.shared.exportActivitiesAsCSV()
        exportText = csv
        showingExportSheet = true
    }
    
    private func exportBaselineData() {
        guard let baseline = BodyBatteryManager.shared.exportBaselineAsString() else {
            exportText = "No baseline data available yet."
            showingExportSheet = true
            return
        }
        exportText = baseline
        showingExportSheet = true
    }
    
    /// Erases all user data from file storage, UserDefaults, and resets managers.
    private func deleteAllUserData() {
        // 1. Clear file-backed data
        PersistenceManager.delete(filename: PersistenceManager.File.batteryHistory)
        PersistenceManager.delete(filename: PersistenceManager.File.stressPredictions)
        PersistenceManager.delete(filename: PersistenceManager.File.recoveryActivities)
        PersistenceManager.delete(filename: PersistenceManager.File.sessionMetrics)
        PersistenceManager.delete(filename: PersistenceManager.File.sleepScore)
        PersistenceManager.delete(filename: PersistenceManager.File.activities)
        PersistenceManager.delete(filename: PersistenceManager.File.detectedActivities)
        
        // 2. Clear UserDefaults scalars
        let keysToRemove = [
            "currentBattery", "sleepDebt", "hrvBaseline", "rhrBaseline",
            "lastLoggedDay_v2", "lastSleepRechargeNight",
            "StressCalculator_BaselineDC", "StressCalculator_BaselineSDNN",
            "notificationsEnabled",
            "hasCompletedOnboarding", "hasSeenWalkthrough",
            "hasCompletedFileMigration_v1"
        ]
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // 3. Reset in-memory managers
        BodyBatteryManager.shared.resetAllBaselines()
        ActivityManager.shared.clearAllActivities()
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)
struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(HealthKitManager())
}
