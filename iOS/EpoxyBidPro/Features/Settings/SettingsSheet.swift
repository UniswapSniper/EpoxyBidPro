import SwiftUI
import ARKit
import RoomPlan

// ─── SettingsSheet ────────────────────────────────────────────────────────────
// Replaces the old More tab. Presented as a sheet from the Dashboard gear icon.
// Contains profile, AI assistant, language, business config, support, and about.

struct SettingsSheet: View {
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue
    @AppStorage("hasSeenFirstTimeTabTooltips") private var hasSeenFirstTimeTabTooltips = false
    @AppStorage("btcPaymentsEnabled") private var btcPaymentsEnabled = false
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var workflowRouter: WorkflowRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented

    private var selectedLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: appLanguageRawValue) ?? .system },
            set: { appLanguageRawValue = $0.rawValue }
        )
    }

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    private var roomPlanAvailable: Bool {
        if #available(iOS 16.0, *) {
            return RoomCaptureSession.isSupported
        }
        return false
    }

    private var arFallbackAvailable: Bool {
        ARWorldTrackingConfiguration.isSupported
    }

    private var profileMonogram: String {
        let source = authStore.userName.isEmpty ? authStore.businessName : authStore.userName
        let letters = source.split(separator: " ").prefix(2).compactMap { $0.first }
        let monogram = String(letters)
        return monogram.isEmpty ? "P" : monogram.uppercased()
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section {
                    profileCard
                }

                // AI Assistant
                Section {
                    NavigationLink {
                        AIAssistantView()
                    } label: {
                        quickAccessRow(
                            title: "AI Assistant",
                            subtitle: "Ask for priorities, follow-up copy, and guidance",
                            systemImage: "message.badge.waveform",
                            tint: .indigo
                        )
                    }
                }

                // Language
                Section {
                    HStack {
                        Label("App Language", systemImage: "globe")
                        Spacer()
                        Picker("", selection: selectedLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayNameKey).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }
                } footer: {
                    Text("Localizes interface labels and status names.")
                }

                // Business
                Section("Business") {
                    NavigationLink {
                        BusinessSetupView()
                    } label: {
                        Label("Company Profile", systemImage: "building.2")
                            .foregroundStyle(.primary)
                    }
                    NavigationLink {
                        SettingsInfoView(
                            title: "Crew",
                            icon: "person.3.fill",
                            message: "Crew assignments are managed per job. Open the Jobs tab and assign crew to specific jobs."
                        )
                    } label: {
                        Label("Crew", systemImage: "person.3.fill")
                    }
                    NavigationLink {
                        SettingsInfoView(
                            title: "Materials",
                            icon: "paintbrush",
                            message: "Material presets and product options are managed inside the bid builder. Go to Pipeline → Bids to configure."
                        )
                    } label: {
                        Label("Materials", systemImage: "paintbrush")
                    }
                    NavigationLink {
                        SettingsInfoView(
                            title: "Templates",
                            icon: "doc.richtext",
                            message: "Proposal templates are managed within the estimate workflow. Go to Pipeline → Bids to create and refine templates."
                        )
                    } label: {
                        Label("Templates", systemImage: "doc.richtext")
                    }
                }

                // Payments
                Section {
                    NavigationLink {
                        BitcoinSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bitcoin Payments")
                                    .font(.subheadline.weight(.medium))
                                Text(btcPaymentsEnabled ? "Enabled" : "Not configured")
                                    .font(.caption)
                                    .foregroundStyle(btcPaymentsEnabled ? EBPColor.success : .secondary)
                            }
                        }
                    }
                } header: {
                    Text("Payments")
                } footer: {
                    Text("Accept Bitcoin and Lightning payments. You receive USD to your bank.")
                }

                // Scanning Capabilities
                Section {
                    HStack {
                        Label("Precision Scan LiDAR", systemImage: "square.fill.on.square.fill")
                        Spacer()
                        Text(roomPlanAvailable ? "Available" : "Unavailable")
                            .foregroundStyle(roomPlanAvailable ? EBPColor.success : EBPColor.danger)
                    }
                    HStack {
                        Label("ARKit Fallback", systemImage: "arkit")
                        Spacer()
                        Text(arFallbackAvailable ? "Ready" : "Unavailable")
                            .foregroundStyle(arFallbackAvailable ? EBPColor.success : EBPColor.danger)
                    }
                    HStack {
                        Label("AI Estimation Engine", systemImage: "brain")
                        Spacer()
                        Text("Local heuristic + backend assist")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("AI + Scanning")
                } footer: {
                    Text("Precision Scan uses LiDAR when available for maximum accuracy.")
                }

                // Operations
                Section("Operations") {
                    NavigationLink {
                        SettingsInfoView(
                            title: "Sync",
                            icon: "icloud.and.arrow.up",
                            message: "Sync status is monitored automatically. Keep internet access enabled for reliable workflow updates."
                        )
                    } label: {
                        Label("Sync", systemImage: "icloud.and.arrow.up")
                    }
                    NavigationLink {
                        SettingsInfoView(
                            title: "Notifications",
                            icon: "bell",
                            message: "Notification routing is active for follow-ups, job updates, and invoice reminders. Adjust preferences in iOS Settings."
                        )
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }

                // Support
                Section("Support") {
                    NavigationLink {
                        SettingsInfoView(
                            title: "FAQ",
                            icon: "questionmark.circle",
                            message: "Use Home for daily priorities, Pipeline for leads and bids, Jobs for production tracking, and Payments for invoicing."
                        )
                    } label: {
                        Label("FAQ", systemImage: "questionmark.circle")
                    }
                    Link(destination: URL(string: "mailto:support@epoxybidpro.com")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    .foregroundStyle(.primary)
                    Link(destination: URL(string: "https://epoxybidpro.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    .foregroundStyle(.primary)
                }

                // Getting Started
                Section {
                    Button {
                        hasSeenFirstTimeTabTooltips = false
                        dismiss()
                        workflowRouter.navigate(to: .dashboard, handoffMessage: "App tour will replay on next launch")
                    } label: {
                        Label("Replay App Tips", systemImage: "lightbulb")
                    }
                } header: {
                    Text("Getting Started")
                } footer: {
                    Text("App tips are shown automatically for first-time users.")
                }

                // About
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Built For", systemImage: "iphone")
                        Spacer()
                        Text("iOS 17+")
                            .foregroundStyle(.secondary)
                    }
                }

                // Sign Out
                Section {
                    Button(role: .destructive) {
                        AppHaptics.trigger(.medium)
                        authStore.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isPresented {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
    }

    private var profileCard: some View {
        NavigationLink {
            BusinessSetupView()
        } label: {
            HStack(spacing: EBPSpacing.md) {
                ZStack {
                    Circle()
                        .fill(EBPColor.primaryGradient)
                        .frame(width: 48, height: 48)
                    Text(profileMonogram)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(authStore.userName.isEmpty ? "User" : authStore.userName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !authStore.businessName.isEmpty {
                        Text(authStore.businessName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("EBP Pro")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EBPColor.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(EBPColor.primary.opacity(0.10))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func quickAccessRow(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: EBPSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.sm)
                    .fill(tint.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Settings Info Detail View

struct SettingsInfoView: View {
    let title: String
    let icon: String
    let message: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.md) {
                Label(title, systemImage: icon)
                    .font(.title3.bold())
                    .foregroundStyle(EBPColor.primary)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EBPSpacing.md)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
