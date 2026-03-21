import SwiftUI
import SwiftData

// ─── AIAssistantView ──────────────────────────────────────────────────────────
// Extracted from MoreView.swift to be standalone.
// Navigated to from SettingsSheet.

struct AIAssistantView: View {
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
            activeTab: "settings",
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
                        viewModel.send(prompt, mode: .dailyBriefing, tone: .direct, context: assistantContext)
                    }

                    actionChip("Follow-up Draft", icon: "bubble.left.and.bubble.right", tint: EBPColor.primary) {
                        let leadName = leads.first?.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let leadText = (leadName?.isEmpty == false) ? leadName ?? "the client" : "the client"
                        let prompt = "Write a short follow-up message for \(leadText) with a soft close and proposed next step."
                        viewModel.send(prompt, mode: .followUpDraft, tone: .friendly, context: assistantContext)
                    }

                    actionChip("Invoice Reminder", icon: "dollarsign.circle", tint: EBPColor.success) {
                        let overdueInvoice = invoices.first(where: { $0.isOverdue })
                        let invoiceNumber = overdueInvoice?.invoiceNumber.isEmpty == false ? (overdueInvoice?.invoiceNumber ?? "[invoice #]") : "[invoice #]"
                        let clientName = overdueInvoice?.client?.displayName ?? "the client"
                        let prompt = "Draft a firm but friendly invoice reminder for \(clientName) about invoice \(invoiceNumber). Include a clear payment call-to-action."
                        viewModel.send(prompt, mode: .invoiceReminder, tone: .concise, context: assistantContext)
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

// MARK: - AI Assistant Supporting Types

@MainActor
final class AIAssistantViewModel: ObservableObject {
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
                ?? "I couldn't reach the assistant backend. Try again shortly."
            messages.append(AssistantMessage(role: .assistant, text: reply))
            isThinking = false
        }
    }
}

protocol AIAssistantServing {
    func reply(
        to message: String,
        mode: AssistantMode,
        tone: AssistantTone,
        context: AssistantContextPayload?
    ) async throws -> String
}

struct AIAssistantService: AIAssistantServing {
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
            return "Start in Pipeline: clear overdue follow-ups first, then work SITE_VISIT leads created in the last 48 hours."
        }
        if lower.contains("bid") || lower.contains("quote") {
            return "Open Pipeline → Bids, run Precision Scan, then Build From Scan to reduce manual entry and tighten pricing consistency."
        }
        if lower.contains("invoice") || lower.contains("collect") {
            return "Open Payments and filter Overdue first. Send reminders before creating new invoices to improve collections pace."
        }
        if lower.contains("job") || lower.contains("crew") || lower.contains("schedule") {
            return "In Jobs, create from signed bids, then use at-risk filtering to catch margin and schedule issues early."
        }
        return "Backend assistant endpoint is ready at /api/v1/assistant/chat. Set assistantAPIBaseURL in UserDefaults to connect your server."
    }
}

struct AssistantRequest: Codable {
    let message: String
    let mode: AssistantMode
    let tone: AssistantTone
    let context: AssistantContextPayload?
}

struct AssistantResponse: Codable {
    let reply: String
}

enum AssistantMode: String, Codable {
    case chat = "chat"
    case dailyBriefing = "daily_briefing"
    case followUpDraft = "follow_up_draft"
    case invoiceReminder = "invoice_reminder"
}

enum AssistantTone: String, Codable {
    case concise = "concise"
    case friendly = "friendly"
    case direct = "direct"
}

struct AssistantContextPayload: Codable {
    let activeTab: String?
    let businessName: String?
    let metrics: AssistantMetrics?
}

struct AssistantMetrics: Codable {
    let leadCount: Int
    let overdueFollowUps: Int
    let draftBidCount: Int
    let scheduledJobCount: Int
    let overdueInvoiceCount: Int
    let openInvoiceBalance: Double
}

struct AssistantMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}
