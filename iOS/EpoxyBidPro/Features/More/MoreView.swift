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
                        CrewManagementView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.crew", comment: ""))
                        } icon: {
                            Image(systemName: "person.3")
                                .foregroundStyle(Color.indigo)
                        }
                    }
                    NavigationLink {
                        MaterialsCatalogView()
                    } label: {
                        Label {
                            Text(NSLocalizedString("more.materials", comment: ""))
                        } icon: {
                            Image(systemName: "paintbrush")
                                .foregroundStyle(EBPColor.warning)
                        }
                    }
                    NavigationLink {
                        BidTemplatesView()
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

private struct AIAssistantView: View {
    @StateObject private var viewModel = AIAssistantViewModel()
    @State private var draft = ""
    @EnvironmentObject private var authStore: AuthStore
    @Query(sort: \Lead.createdAt, order: .reverse) private var leads: [Lead]
    @Query(sort: \Bid.createdAt, order: .reverse) private var bids: [Bid]
    @Query(sort: \Job.createdAt, order: .reverse) private var jobs: [Job]
    @Query(sort: \Invoice.createdAt, order: .reverse) private var invoices: [Invoice]

    private let starterPrompts = [
        "What should I work on first today?",
        "How can I improve bid win rate this week?",
        "Give me a client follow-up message template",
    ]

    private var latestAssistantReply: String? {
        viewModel.messages.last(where: { $0.role == .assistant })?.text
    }

    private var overdueFollowUps: Int {
        let now = Date()
        return leads.filter {
            guard let followUp = $0.followUpAt else { return false }
            let status = $0.status.uppercased()
            return followUp < now && status != "WON" && status != "LOST" && status != "CONVERTED"
        }.count
    }

    private var draftBidCount: Int {
        bids.filter { $0.status.uppercased() == "DRAFT" }.count
    }

    private var scheduledJobCount: Int {
        jobs.filter {
            let status = $0.status.uppercased()
            return status == "SCHEDULED" || status == "IN_PROGRESS"
        }.count
    }

    private var overdueInvoiceCount: Int {
        invoices.filter { $0.isOverdue }.count
    }

    private var openInvoiceBalance: Double {
        invoices.reduce(0) { partial, invoice in
            partial + NSDecimalNumber(decimal: invoice.balanceDue).doubleValue
        }
    }

    private var assistantContext: AssistantContextPayload {
        AssistantContextPayload(
            activeTab: "more",
            businessName: authStore.businessName.isEmpty ? nil : authStore.businessName,
            metrics: AssistantMetrics(
                leadCount: leads.count,
                overdueFollowUps: overdueFollowUps,
                draftBidCount: draftBidCount,
                scheduledJobCount: scheduledJobCount,
                overdueInvoiceCount: overdueInvoiceCount,
                openInvoiceBalance: openInvoiceBalance
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        quickActions

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = latestAssistantReply
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .disabled((latestAssistantReply ?? "").isEmpty)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text("AI Workflows")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    actionChip("Daily Briefing", icon: "sun.max", tint: .orange) {
                        let prompt = "Create my daily briefing using these numbers. Prioritize what I should do in the next 2 hours and include one specific next action in the app."
                        viewModel.send(
                            prompt,
                            mode: .dailyBriefing,
                            tone: .direct,
                            context: assistantContext
                        )
                    }

                    actionChip("Follow-up Draft", icon: "bubble.left.and.bubble.right", tint: EBPColor.primary) {
                        let leadName = leads.first?.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let leadText = (leadName?.isEmpty == false) ? leadName ?? "the client" : "the client"
                        let prompt = "Write a short follow-up message for \(leadText) with a soft close and proposed next step."
                        viewModel.send(
                            prompt,
                            mode: .followUpDraft,
                            tone: .friendly,
                            context: assistantContext
                        )
                    }

                    actionChip("Invoice Reminder", icon: "dollarsign.circle", tint: EBPColor.success) {
                        let overdueInvoice = invoices.first(where: { $0.isOverdue })
                        let invoiceNumber = overdueInvoice?.invoiceNumber.isEmpty == false ? (overdueInvoice?.invoiceNumber ?? "[invoice #]") : "[invoice #]"
                        let clientName = overdueInvoice?.client?.displayName ?? "the client"
                        let prompt = "Draft a firm but friendly invoice reminder for \(clientName) about invoice \(invoiceNumber). Include a clear payment call-to-action."
                        viewModel.send(
                            prompt,
                            mode: .invoiceReminder,
                            tone: .concise,
                            context: assistantContext
                        )
                    }
                }
                .padding(.horizontal, EBPSpacing.md)
            }

            HStack(spacing: 8) {
                metricPill(title: "Overdue FU", value: "\(overdueFollowUps)", color: .orange)
                metricPill(title: "Draft Bids", value: "\(draftBidCount)", color: EBPColor.primary)
                metricPill(title: "Overdue Inv", value: "\(overdueInvoiceCount)", color: EBPColor.success)
            }
            .padding(.horizontal, EBPSpacing.md)
        }
        .padding(.top, EBPSpacing.md)
    }

    private func actionChip(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isThinking)
    }

    private func metricPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(EBPColor.surface.opacity(0.3), in: Capsule())
    }

    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = ""
        viewModel.send(trimmed, mode: .chat, tone: .concise, context: assistantContext)
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

    func send(
        _ userText: String,
        mode: AssistantMode = .chat,
        tone: AssistantTone = .concise,
        context: AssistantContextPayload? = nil
    ) {
        messages.append(AssistantMessage(role: .user, text: userText))
        isThinking = true

        Task {
            let reply = (try? await service.reply(to: userText, mode: mode, tone: tone, context: context))
                ?? "I couldn’t reach the assistant backend. Try again shortly."
            messages.append(AssistantMessage(role: .assistant, text: reply))
            isThinking = false
        }
    }
}

private protocol AIAssistantServing {
    func reply(
        to message: String,
        mode: AssistantMode,
        tone: AssistantTone,
        context: AssistantContextPayload?
    ) async throws -> String
}

private struct AIAssistantService: AIAssistantServing {
    func reply(
        to message: String,
        mode: AssistantMode,
        tone: AssistantTone,
        context: AssistantContextPayload?
    ) async throws -> String {
        let baseURLString = UserDefaults.standard.string(forKey: "assistantAPIBaseURL")
            ?? "http://localhost:3000"

        guard let url = URL(string: "\(baseURLString)/api/v1/assistant/chat") else {
            return localFallback(for: message)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AssistantRequest(
                message: message,
                mode: mode,
                tone: tone,
                context: context
            )
        )

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
        return "Backend assistant endpoint is ready at /api/v1/assistant/chat. Set assistantAPIBaseURL in UserDefaults to connect your server."
    }
}

private struct AssistantRequest: Codable {
    let message: String
    let mode: AssistantMode
    let tone: AssistantTone
    let context: AssistantContextPayload?
}

private struct AssistantResponse: Codable {
    let reply: String
}

private enum AssistantMode: String, Codable {
    case chat = "chat"
    case dailyBriefing = "daily_briefing"
    case followUpDraft = "follow_up_draft"
    case invoiceReminder = "invoice_reminder"
}

private enum AssistantTone: String, Codable {
    case concise = "concise"
    case friendly = "friendly"
    case direct = "direct"
}

private struct AssistantContextPayload: Codable {
    let activeTab: String?
    let businessName: String?
    let metrics: AssistantMetrics?
}

private struct AssistantMetrics: Codable {
    let leadCount: Int
    let overdueFollowUps: Int
    let draftBidCount: Int
    let scheduledJobCount: Int
    let overdueInvoiceCount: Int
    let openInvoiceBalance: Double
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

