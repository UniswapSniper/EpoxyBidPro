import SwiftUI
import SwiftData
import ARKit
import RoomPlan

// ─── SettingsSheet ───────────────────────────────────────────────────────────
// Replaces the More tab. Presented as a sheet from the Home tab's gear icon.

struct SettingsSheet: View {
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue
    @AppStorage("hasSeenFirstTimeTabTooltips") private var hasSeenFirstTimeTabTooltips = false
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var workflowRouter: WorkflowRouter
    @Environment(\.dismiss) private var dismiss

    private var selectedLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: appLanguageRawValue) ?? .system },
            set: { appLanguageRawValue = $0.rawValue }
        )
    }

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    private var roomPlanAvailable: Bool {
        if #available(iOS 16.0, *) { return RoomCaptureSession.isSupported }
        return false
    }

    private var arFallbackAvailable: Bool { ARWorldTrackingConfiguration.isSupported }
    private var aiInsightsMode: String { "Local heuristic + backend assist" }

    var body: some View {
        NavigationStack {
            List {
                // ── Profile Header ───────────────────────────────────────
                Section {
                    HStack(spacing: EBPSpacing.md) {
                        ZStack {
                            Circle().fill(EBPColor.primaryGradient).frame(width: 56, height: 56)
                            Text(String(authStore.userName.prefix(1)).uppercased())
                                .font(.title2.bold()).foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(authStore.userName.isEmpty ? NSLocalizedString("more.user", comment: "") : authStore.userName)
                                .font(.headline)
                            if !authStore.businessName.isEmpty {
                                Text(authStore.businessName).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(NSLocalizedString("more.pro", comment: ""))
                                .font(.caption).foregroundStyle(EBPColor.primary)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(EBPColor.primary.opacity(0.10)).clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(.vertical, EBPSpacing.xs)
                }

                // ── AI Assistant ─────────────────────────────────────────
                Section {
                    NavigationLink { AIAssistantView() } label: {
                        Label("AI Assistant", systemImage: "message.badge.waveform")
                    }
                } header: {
                    Text("AI + Scanning")
                }

                // ── Language ─────────────────────────────────────────────
                Section {
                    HStack {
                        Label(NSLocalizedString("more.appLanguage", comment: ""), systemImage: "globe")
                        Spacer()
                        Picker("", selection: selectedLanguage) {
                            ForEach(AppLanguage.allCases) { lang in Text(lang.displayNameKey).tag(lang) }
                        }
                        .pickerStyle(.menu).tint(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("more.language", comment: ""))
                } footer: {
                    Text(NSLocalizedString("more.langDesc", comment: ""))
                }

                // ── Business ─────────────────────────────────────────────
                Section(NSLocalizedString("more.business", comment: "")) {
                    NavigationLink { BusinessSetupView() } label: {
                        Label { Text(NSLocalizedString("more.companyProfile", comment: "")) } icon: {
                            Image(systemName: "building.2").foregroundStyle(EBPColor.primary)
                        }
                    }
                    NavigationLink { JobsView() } label: {
                        Label { Text(NSLocalizedString("more.crew", comment: "")) } icon: {
                            Image(systemName: "person.3").foregroundStyle(Color.indigo)
                        }
                    }
                    NavigationLink { BidsView() } label: {
                        Label { Text(NSLocalizedString("more.materials", comment: "")) } icon: {
                            Image(systemName: "paintbrush").foregroundStyle(EBPColor.warning)
                        }
                    }
                    NavigationLink { BidsView() } label: {
                        Label { Text(NSLocalizedString("more.templates", comment: "")) } icon: {
                            Image(systemName: "doc.richtext").foregroundStyle(Color.purple)
                        }
                    }
                }

                // ── Scanning Capabilities ────────────────────────────────
                Section {
                    HStack {
                        Label("RoomPlan LiDAR", systemImage: "square.fill.on.square.fill")
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
                        Text(aiInsightsMode).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Scanning")
                } footer: {
                    Text("Scanning defaults to RoomPlan on LiDAR-capable devices and falls back to ARKit perimeter scanning when needed.")
                }

                // ── Operations ────────────────────────────────────────────
                Section(NSLocalizedString("more.operations", comment: "")) {
                    NavigationLink {
                        MoreInfoView(title: NSLocalizedString("more.sync", comment: ""), icon: "icloud.and.arrow.up",
                                     message: "Sync status is monitored automatically. Keep internet access enabled for reliable workflow updates.")
                    } label: {
                        Label { Text(NSLocalizedString("more.sync", comment: "")) } icon: {
                            Image(systemName: "icloud.and.arrow.up").foregroundStyle(.blue)
                        }
                    }
                    NavigationLink {
                        MoreInfoView(title: NSLocalizedString("more.notifications", comment: ""), icon: "bell",
                                     message: "Notification routing is active for follow-ups, job updates, and invoice reminders. System-level notification preferences can be adjusted in iOS Settings.")
                    } label: {
                        Label { Text(NSLocalizedString("more.notifications", comment: "")) } icon: {
                            Image(systemName: "bell").foregroundStyle(Color.orange)
                        }
                    }
                }

                // ── Support ──────────────────────────────────────────────
                Section(NSLocalizedString("more.support", comment: "")) {
                    NavigationLink {
                        MoreInfoView(title: NSLocalizedString("more.faq", comment: ""), icon: "questionmark.circle",
                                     message: "Use Home for daily priorities, Pipeline for leads and bids, Jobs for production tracking, and Payments for invoicing.")
                    } label: {
                        Label { Text(NSLocalizedString("more.faq", comment: "")) } icon: {
                            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                        }
                    }
                    Link(destination: URL(string: "mailto:support@epoxybidpro.com")!) {
                        Label { Text(NSLocalizedString("more.contact", comment: "")) } icon: {
                            Image(systemName: "envelope").foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    Link(destination: URL(string: "https://epoxybidpro.com/privacy")!) {
                        Label { Text(NSLocalizedString("more.privacy", comment: "")) } icon: {
                            Image(systemName: "hand.raised").foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // ── Getting Started ──────────────────────────────────────
                Section {
                    Button {
                        hasSeenFirstTimeTabTooltips = false
                        dismiss()
                        workflowRouter.navigate(to: .home, handoffMessage: "App tour will replay on next launch")
                    } label: {
                        Label("Replay App Tips", systemImage: "lightbulb")
                    }
                } header: {
                    Text("Getting Started")
                } footer: {
                    Text("App tips are shown automatically for first-time users and can be replayed anytime.")
                }

                // ── About ────────────────────────────────────────────────
                Section(NSLocalizedString("more.about", comment: "")) {
                    HStack {
                        Label(NSLocalizedString("more.version", comment: ""), systemImage: "info.circle")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label(NSLocalizedString("more.builtFor", comment: ""), systemImage: "iphone")
                        Spacer()
                        Text(NSLocalizedString("more.ios17", comment: "")).foregroundStyle(.secondary)
                    }
                }

                // ── Sign Out ─────────────────────────────────────────────
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// Keep MoreInfoView accessible for navigation links
struct MoreInfoView: View {
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
