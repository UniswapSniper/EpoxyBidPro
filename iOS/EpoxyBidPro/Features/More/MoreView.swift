import SwiftUI

struct MoreView: View {
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.english.rawValue
    @EnvironmentObject private var authStore: AuthStore

    private var selectedLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: appLanguageRawValue) ?? .english },
            set: { appLanguageRawValue = $0.rawValue }
        )
    }

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

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
                            Text("J")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Jeff Goldner")
                                .font(.headline)
                            Text("EpoxyBidPro Pro")
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
                } header: {
                    Text("Language")
                } footer: {
                    Text("Choose how text appears throughout the app.")
                }

                // ── Business ───────────────────────────────────────────────
                Section("Business") {
                    moreRow(icon: "building.2",       label: "Company Profile",   tint: EBPColor.primary)
                    moreRow(icon: "person.3",         label: "Crew Members",       tint: Color.indigo)
                    moreRow(icon: "paintbrush",       label: "Material Catalogue", tint: EBPColor.warning)
                    moreRow(icon: "doc.richtext",     label: "Proposal Templates", tint: Color.purple)
                }

                // ── Operations ─────────────────────────────────────────────
                Section("Operations") {
                    moreRow(icon: "dollarsign.circle", label: "Invoicing & Payments", tint: EBPColor.success)
                    moreRow(icon: "doc.text.magnifyingglass", label: "Reports",       tint: Color.teal)
                    moreRow(icon: "icloud.and.arrow.up",      label: "Sync Status",   tint: .blue)
                    moreRow(icon: "bell",              label: "Notifications",         tint: Color.orange)
                }

                // ── Support ─────────────────────────────────────────────────
                Section("Support") {
                    moreRow(icon: "questionmark.circle", label: "Help & FAQ",      tint: .secondary)
                    moreRow(icon: "envelope",            label: "Contact Support", tint: .secondary)
                    Link(destination: URL(string: "https://epoxybidpro.com/privacy")!) {
                        Label {
                            Text("Privacy Policy")
                        } icon: {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // ── About ──────────────────────────────────────────────────
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Built for", systemImage: "iphone")
                        Spacer()
                        Text("iOS 17+")
                            .foregroundStyle(.secondary)
                    }
                }

                // ── Sign Out ───────────────────────────────────────────────
                Section {
                    Button(role: .destructive) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Row Helper

    private func moreRow(icon: String, label: String, tint: Color) -> some View {
        HStack {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiaryLabel)
        }
    }
}

// ─── Color helper for tertiaryLabel ──────────────────────────────────────────

private extension Color {
    static let tertiaryLabel = Color(.tertiaryLabel)
}

