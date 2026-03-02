import SwiftUI
import SwiftData
import ARKit
import RoomPlan

struct MoreView: View {
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue
    @AppStorage("dockHapticMode") private var dockHapticMode = "strong"
    @AppStorage("hasSeenFirstTimeTabTooltips") private var hasSeenFirstTimeTabTooltips = false
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
                                .foregroundStyle(.white)
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
                        JobsView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.crew", comment: ""))
                        } icon: {
                            Image(systemName: "person.3")
                                .foregroundStyle(Color.indigo)
                        }
                    }
                    NavigationLink {
                        BidsView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.materials", comment: ""))
                        } icon: {
                            Image(systemName: "paintbrush")
                                .foregroundStyle(EBPColor.warning)
                        }
                    }
                    NavigationLink {
                        BidsView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.templates", comment: ""))
                        } icon: {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(Color.purple)
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
                                .foregroundStyle(Color.teal)
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
                                .foregroundStyle(.blue)
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
                                .foregroundStyle(Color.orange)
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
                        Text(aiInsightsMode)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
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

private struct AIAssistantView: View {
    @StateObject private var viewModel = AIAssistantViewModel()
    @State private var draft = ""

    private let starterPrompts = [
        "What should I work on first today?",
        "How can I improve bid win rate this week?",
        "Give me a client follow-up message template",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        if viewModel.messages.count <= 1 {
                            VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                                Text("Try a quick prompt")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(starterPrompts, id: \.self) { prompt in
                                    Button(prompt) {
                                        submit(prompt)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(EBPColor.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(EBPColor.primary.opacity(0.08), in: Capsule())
                                }
                            }
                            .padding(.horizontal, EBPSpacing.md)
                            .padding(.top, EBPSpacing.md)
                        }

                        ForEach(viewModel.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if viewModel.isThinking {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Assistant is thinking…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, EBPSpacing.md)
                            .padding(.top, EBPSpacing.sm)
                        }
                    }
                    .padding(.vertical, EBPSpacing.md)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    guard let lastId = viewModel.messages.last?.id else { return }
                    withAnimation(EBPAnimation.smooth) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack(spacing: EBPSpacing.sm) {
                TextField("Ask the assistant…", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    submit(draft)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : EBPColor.primary)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isThinking)
            }
            .padding(EBPSpacing.md)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = ""
        viewModel.send(trimmed)
    }

    private func messageBubble(_ message: AssistantMessage) -> some View {
        HStack {
            if message.role == .assistant {
                Label("", systemImage: "brain")
                    .foregroundStyle(EBPColor.primary)
                    .padding(.top, 4)
            } else {
                Spacer(minLength: 0)
            }

            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(message.role == .assistant ? Color.primary : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    message.role == .assistant
                    ? AnyShapeStyle(EBPColor.surface.opacity(0.35))
                    : AnyShapeStyle(EBPColor.primaryGradient)
                , in: RoundedRectangle(cornerRadius: EBPRadius.md))

            if message.role == .assistant {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, EBPSpacing.md)
    }
}

@MainActor
private final class AIAssistantViewModel: ObservableObject {
    @Published var messages: [AssistantMessage] = [
        AssistantMessage(
            role: .assistant,
            text: "I can help with leads, bids, scheduling, invoices, and client communication. Ask anything."
        )
    ]
    @Published var isThinking = false

    private let service: AIAssistantServing

    init(service: AIAssistantServing = AIAssistantService()) {
        self.service = service
    }

    func send(_ userText: String) {
        messages.append(AssistantMessage(role: .user, text: userText))
        isThinking = true

        Task {
            let reply = (try? await service.reply(to: userText))
                ?? "I couldn’t reach the assistant backend. Try again shortly."
            messages.append(AssistantMessage(role: .assistant, text: reply))
            isThinking = false
        }
    }
}

private protocol AIAssistantServing {
    func reply(to message: String) async throws -> String
}

private struct AIAssistantService: AIAssistantServing {
    func reply(to message: String) async throws -> String {
        let baseURLString = UserDefaults.standard.string(forKey: "assistantAPIBaseURL")
            ?? "http://localhost:3000"

        guard let url = URL(string: "\(baseURLString)/api/v1/assistant/chat") else {
            return localFallback(for: message)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AssistantRequest(message: message))

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return localFallback(for: message)
            }
            let payload = try JSONDecoder().decode(AssistantResponse.self, from: data)
            return payload.reply
        } catch {
            return localFallback(for: message)
        }
    }

    private func localFallback(for message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("follow") || lower.contains("lead") {
            return "Start in CRM: clear overdue follow-ups first, then work SITE_VISIT leads created in the last 48 hours."
        }
        if lower.contains("bid") || lower.contains("quote") {
            return "Open Bids, run Scan Space, then Build From Scan to reduce manual entry and tighten pricing consistency."
        }
        if lower.contains("invoice") || lower.contains("collect") {
            return "Open Invoicing and filter Overdue first. Send reminders before creating new invoices to improve collections pace."
        }
        if lower.contains("job") || lower.contains("crew") || lower.contains("schedule") {
            return "In Jobs, create from signed bids, then use at-risk filtering to catch margin and schedule issues early."
        }
        return "Backend assistant endpoint is ready at /api/assistant/chat. Set assistantAPIBaseURL in UserDefaults to connect your server."
    }
}

private struct AssistantRequest: Codable {
    let message: String
}

private struct AssistantResponse: Codable {
    let reply: String
}

private struct AssistantMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

// ─── Color helper for tertiaryLabel ──────────────────────────────────────────

private extension Color {
    static let tertiaryLabel = Color(.tertiaryLabel)
}

