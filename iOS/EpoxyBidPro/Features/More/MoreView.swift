import SwiftUI
import SwiftData
import ARKit
import RoomPlan
import UIKit

struct MoreView: View {
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue
    @AppStorage("dockHapticMode") private var dockHapticMode = "strong"
    @AppStorage("hasSeenFirstTimeTabTooltips") private var hasSeenFirstTimeTabTooltips = false
    @AppStorage("assistantAPIBaseURL") private var assistantAPIBaseURL = "http://localhost:3000"
    @State private var showServerURLEditor = false
    @State private var serverURLDraft = ""
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var workflowRouter: WorkflowRouter

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

    private var aiInsightsMode: String {
        "Local heuristic + backend assist"
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Profile Header ─────────────────────────────────────────
                Section {
                    HStack(spacing: EBPSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(EBPColor.primaryGradient)
                                .frame(width: 56, height: 56)
                            Text(String(authStore.userName.prefix(1)).uppercased())
                                .font(.title2.bold())
                                .foregroundStyle(EBPColor.onSurface)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(authStore.userName.isEmpty ? NSLocalizedString("more.user", comment: "") : authStore.userName)
                                .font(.headline)
                            if !authStore.businessName.isEmpty {
                                Text(authStore.businessName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(NSLocalizedString("more.pro", comment: ""))
                                .font(.caption)
                                .foregroundStyle(EBPColor.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(EBPColor.primary.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, EBPSpacing.xs)
                }

                // ── Language ───────────────────────────────────────────────
                Section {
                    HStack {
                        Label(NSLocalizedString("more.appLanguage", comment: ""), systemImage: "globe")
                        Spacer()
                        Picker("", selection: selectedLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayNameKey).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("more.language", comment: ""))
                } footer: {
                    Text(NSLocalizedString("more.langDesc", comment: ""))
                }

                // ── Business ───────────────────────────────────────────────
                Section(NSLocalizedString("more.business", comment: "")) {
                    NavigationLink {
                        BusinessSetupView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.companyProfile", comment: ""))
                        } icon: {
                            Image(systemName: "building.2")
                                .foregroundStyle(EBPColor.primary)
                        }
                    }
                    NavigationLink {
                        CrewManagementView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.crew", comment: ""))
                        } icon: {
                            Image(systemName: "person.3")
                                .foregroundStyle(EBPColor.primaryFixedDim)
                        }
                    }
                    NavigationLink {
                        MaterialsCatalogView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.materials", comment: ""))
                        } icon: {
                            Image(systemName: "paintbrush")
                                .foregroundStyle(EBPColor.secondary)
                        }
                    }
                    NavigationLink {
                        BidTemplatesView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.templates", comment: ""))
                        } icon: {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(EBPColor.tertiary)
                        }
                    }
                }

                // ── Operations ─────────────────────────────────────────────
                Section(NSLocalizedString("more.operations", comment: "")) {
                    NavigationLink {
                        InvoicingView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.invoicing", comment: ""))
                        } icon: {
                            Image(systemName: "dollarsign.circle")
                                .foregroundStyle(EBPColor.success)
                        }
                    }
                    NavigationLink {
                        AnalyticsView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.reports", comment: ""))
                        } icon: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(EBPColor.primaryContainer)
                        }
                    }
                    NavigationLink {
                        MoreInfoView(
                            title: NSLocalizedString("more.sync", comment: ""),
                            icon: "icloud.and.arrow.up",
                            message: "Sync status is monitored automatically. Keep internet access enabled for reliable workflow updates."
                        )
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.sync", comment: ""))
                        } icon: {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundStyle(EBPColor.primary)
                        }
                    }
                    NavigationLink {
                        MoreInfoView(
                            title: NSLocalizedString("more.notifications", comment: ""),
                            icon: "bell",
                            message: "Notification routing is active for follow-ups, job updates, and invoice reminders. System-level notification preferences can be adjusted in iOS Settings."
                        )
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.notifications", comment: ""))
                        } icon: {
                            Image(systemName: "bell")
                                .foregroundStyle(EBPColor.secondaryContainer)
                        }
                    }
                }

                // ── AI + Scanning Platform ─────────────────────────────────
                Section {
                    NavigationLink {
                        AIAssistantView()
                    } label: {
                        Label("AI Assistant", systemImage: "message.badge.waveform")
                    }

                    HStack {
                        Label("RoomPlan LiDAR", systemImage: "square.fill.on.square.fill")
                        Spacer()
                        Text(roomPlanAvailable ? "Available" : "Unavailable")
                            .foregroundStyle(roomPlanAvailable ? EBPColor.success : EBPColor.error)
                    }

                    HStack {
                        Label("ARKit Fallback", systemImage: "arkit")
                        Spacer()
                        Text(arFallbackAvailable ? "Ready" : "Unavailable")
                            .foregroundStyle(arFallbackAvailable ? EBPColor.success : EBPColor.error)
                    }

                    HStack {
                        Label("AI Estimation Engine", systemImage: "brain")
                        Spacer()
                        Text(aiInsightsMode)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    serverURLRow
                } header: {
                    Text("AI + Scanning")
                } footer: {
                    Text("Scanning defaults to RoomPlan on LiDAR-capable devices and falls back to ARKit perimeter scanning when needed.")
                }

                // ── Interaction ────────────────────────────────────────────
                Section {
                    Picker("Dock Haptics", selection: $dockHapticMode) {
                        Text("Strong").tag("strong")
                        Text("Subtle").tag("subtle")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Interaction")
                } footer: {
                    Text("Controls haptic intensity for global quick-action dock taps.")
                }

                // ── Support ─────────────────────────────────────────────────
                Section(NSLocalizedString("more.support", comment: "")) {
                    NavigationLink {
                        MoreInfoView(
                            title: NSLocalizedString("more.faq", comment: ""),
                            icon: "questionmark.circle",
                            message: "Use Dashboard for daily priorities, CRM for follow-ups, Bids for estimate generation, and Jobs for production tracking."
                        )
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.faq", comment: ""))
                        } icon: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Link(destination: URL(string: "mailto:support@epoxybidpro.com")!) {
                        Label {
                            Text(NSLocalizedString("more.contact", comment: ""))
                        } icon: {
                            Image(systemName: "envelope")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    Link(destination: URL(string: "https://epoxybidpro.com/privacy")!) {
                        Label {
                            Text(NSLocalizedString("more.privacy", comment: ""))
                        } icon: {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    Button {
                        hasSeenFirstTimeTabTooltips = false
                        workflowRouter.navigate(to: .dashboard, handoffMessage: "App tour will replay on next launch")
                    } label: {
                        Label("Replay App Tips", systemImage: "lightbulb")
                    }
                } header: {
                    Text("Getting Started")
                } footer: {
                    Text("App tips are shown automatically for first-time users and can be replayed anytime.")
                }

                // ── About ──────────────────────────────────────────────────
                Section(NSLocalizedString("more.about", comment: "")) {
                    HStack {
                        Label(NSLocalizedString("more.version", comment: ""), systemImage: "info.circle")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label(NSLocalizedString("more.builtFor", comment: ""), systemImage: "iphone")
                        Spacer()
                        Text(NSLocalizedString("more.ios17", comment: ""))
                            .foregroundStyle(.secondary)
                    }
                }

                // ── Sign Out ───────────────────────────────────────────────
                Section {
                    Button(role: .destructive) {
                        AppHaptics.trigger(.medium)
                        authStore.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Label(NSLocalizedString("more.signOut", comment: ""), systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("more.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct MoreInfoView: View {
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

// ─── Server URL Row ───────────────────────────────────────────────────────────

extension MoreView {
    var serverURLRow: some View {
        Button {
            serverURLDraft = assistantAPIBaseURL
            showServerURLEditor = true
        } label: {
            HStack {
                Label("Server URL", systemImage: "network")
                Spacer()
                Text(assistantAPIBaseURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 140, alignment: .trailing)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
        .alert("Backend Server URL", isPresented: $showServerURLEditor) {
            TextField("http://localhost:3000", text: $serverURLDraft)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Save") {
                let trimmed = serverURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    assistantAPIBaseURL = trimmed
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your backend server base URL (e.g. https://api.epoxybidpro.com)")
        }
    }
}

// ─── Crew Management View ─────────────────────────────────────────────────────

struct CrewManagementView: View {
    @Query(sort: \CrewMember.firstName) private var crewMembers: [CrewMember]

    var body: some View {
        Group {
            if crewMembers.isEmpty {
                ContentUnavailableView(
                    "No Crew Members",
                    systemImage: "person.3.fill",
                    description: Text("Add crew members in the full crew management module.")
                )
            } else {
                List(crewMembers) { member in
                    VStack(alignment: .leading, spacing: 4) {
                        Text([member.firstName, member.lastName].filter { !$0.isEmpty }.joined(separator: " "))
                            .font(.headline)
                        HStack {
                            Text(member.role.isEmpty ? "No role" : member.role)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            EBPBadge(
                                text: member.isActive ? "Active" : "Inactive",
                                color: member.isActive ? EBPColor.success : .secondary
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Crew")
        .navigationBarTitleDisplayMode(.large)
    }
}

// ─── Materials Catalog View ───────────────────────────────────────────────────

struct MaterialsCatalogView: View {
    @Query(sort: \Material.name) private var materials: [Material]

    var body: some View {
        Group {
            if materials.isEmpty {
                ContentUnavailableView(
                    "No Materials",
                    systemImage: "paintbrush.fill",
                    description: Text("Your epoxy product catalog will appear here once materials are added.")
                )
            } else {
                List(materials) { material in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(material.name)
                            .font(.headline)
                        HStack(spacing: EBPSpacing.md) {
                            if material.costPerUnit > 0 {
                                Label("$\(String(format: "%.2f", Double(truncating: material.costPerUnit as NSNumber)))/\(material.unit)", systemImage: "dollarsign.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if material.coverageRate > 0 {
                                Label("\(Int(material.coverageRate)) sf/\(material.unit)", systemImage: "square.dashed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !material.brand.isEmpty {
                                Text(material.brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Materials")
        .navigationBarTitleDisplayMode(.large)
    }
}

// ─── Bid Templates View ───────────────────────────────────────────────────────

struct BidTemplatesView: View {
    @Query(sort: \Template.name) private var templates: [Template]

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No Templates",
                    systemImage: "doc.richtext",
                    description: Text("Save a completed bid as a template to reuse scope, pricing, and line items for similar jobs.")
                )
            } else {
                List(templates) { template in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                        Text(template.type.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.large)
    }
}

// ─── Color helper for tertiaryLabel ──────────────────────────────────────────

private extension Color {
    static let tertiaryLabel = Color(.tertiaryLabel)
}
