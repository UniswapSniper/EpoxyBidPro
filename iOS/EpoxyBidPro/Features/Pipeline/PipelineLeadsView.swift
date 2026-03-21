import SwiftUI
import SwiftData

struct PipelineLeadsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    
    var allLeads: [Lead]
    var searchText: String
    
    @Binding var selectedLead: Lead?
    @Binding var segment: PipelineView.Segment

    private var overdueFollowUps: Int {
        allLeads.filter { ($0.followUpDate ?? .distantFuture) < Date() && !["WON", "LOST"].contains($0.status) }.count
    }

    private var actionableLeads: [Lead] {
        allLeads
            .filter { !["WON", "LOST"].contains($0.status) }
            .sorted { EpoxyAIWorkflowAdvisor.followUpPriorityScore($0) > EpoxyAIWorkflowAdvisor.followUpPriorityScore($1) }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: EBPSpacing.md) {
            pipelineSummaryBar
            followUpAutomationQueue

            ForEach(CRMLeadStage.allCases) { stage in
                kanbanColumn(stage: stage)
            }
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.bottom, EBPSpacing.xl)
    }

    private var pipelineSummaryBar: some View {
        let newCount = allLeads.filter { $0.status == "NEW" }.count
        let totalValue = allLeads
            .filter { !["WON", "LOST"].contains($0.status) }
            .reduce(0.0) { $0 + $1.estimatedValue }
        let wonCount = allLeads.filter { $0.status == "WON" }.count
        let overdue = overdueFollowUps

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: EBPSpacing.sm) {
            EBPStatCard(title: "Total Leads", value: "\(allLeads.count)", icon: "person.2.fill", tint: EBPColor.accent)
            EBPStatCard(title: "New", value: "\(newCount)", icon: "sparkles", tint: .blue)
            EBPStatCard(title: "Won", value: "\(wonCount)", icon: "checkmark.seal.fill", tint: EBPColor.success)
            EBPStatCard(
                title: overdue > 0 ? "Overdue Follow-ups" : "Pipeline",
                value: overdue > 0 ? "\(overdue)" : formatCurrency(totalValue),
                icon: overdue > 0 ? "calendar.badge.exclamationmark" : "dollarsign.circle.fill",
                tint: overdue > 0 ? EBPColor.warning : EBPColor.primary,
                isAlert: overdue > 0
            )
        }
    }

    private var followUpAutomationQueue: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Label("AI Follow-Up Queue", systemImage: "brain")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(actionableLeads.count) next")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if actionableLeads.isEmpty {
                Text("No urgent follow-ups. Your pipeline is clear right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, EBPSpacing.xs)
            } else {
                ForEach(actionableLeads) { lead in
                    followUpLeadRow(lead)
                }
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        .animation(EBPAnimation.sectionSwitch, value: actionableLeads.count)
    }

    private func followUpLeadRow(_ lead: Lead) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead.displayName.isEmpty ? "Unnamed Lead" : lead.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(followUpSuggestion(for: lead))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                }
                Spacer()
                Text("\(EpoxyAIWorkflowAdvisor.leadCloseProbability(lead))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EBPColor.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            HStack(spacing: EBPSpacing.sm) {
                primaryFollowUpButton(for: lead)

                Button { completeFollowUp(lead) } label: {
                    Text("Mark Contacted")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(EBPColor.accent, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                }
                .buttonStyle(.plain)

                Button { snoozeFollowUp(lead) } label: {
                    Text("Snooze 1d")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: EBPRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EBPSpacing.sm)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
        .contentShape(RoundedRectangle(cornerRadius: EBPRadius.sm))
        .onTapGesture { selectedLead = lead }
    }

    private func kanbanColumn(stage: CRMLeadStage) -> some View {
        let leads = filteredLeads(for: stage)
        let totalValue = leads.reduce(0.0) { $0 + $1.estimatedValue }

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.xs) {
                Circle().fill(stage.color).frame(width: 8, height: 8)
                Text(stage.label)
                    .font(.subheadline.weight(.bold))
                Spacer()
                EBPBadge(text: "\(leads.count)", color: stage.color)
            }

            if totalValue > 0 {
                Text(formatCurrency(totalValue))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stage.color)
            }

            if leads.isEmpty {
                VStack(spacing: EBPSpacing.xs) {
                    Image(systemName: "tray")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stage.color.opacity(0.8))
                    Text("No leads")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: EBPRadius.sm)
                        .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
            } else {
                ForEach(leads) { lead in
                    leadCard(lead, stage: stage)
                }
            }
        }
        .padding(EBPSpacing.sm)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func leadCard(_ lead: Lead, stage: CRMLeadStage) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                HStack {
                    Text(lead.displayName.isEmpty ? "Unnamed Lead" : lead.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    if lead.estimatedValue > 0 {
                        Text(formatCurrency(lead.estimatedValue))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(stage.color)
                    }
                }
                if !lead.company.isEmpty {
                    Text(lead.company)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                HStack(spacing: EBPSpacing.xs) {
                    if !lead.source.isEmpty {
                        EBPPillTag(text: lead.source.capitalized, color: .secondary)
                    }
                    if let followUp = lead.followUpDate {
                        HStack(spacing: 2) {
                            Image(systemName: followUp < Date() ? "exclamationmark.triangle.fill" : "calendar")
                                .font(.system(size: 8))
                                .foregroundStyle(followUp < Date() ? EBPColor.danger : .secondary)
                            Text(followUp.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(followUp < Date() ? EBPColor.danger : .white.opacity(0.65))
                        }
                    }
                }
                Text(followUpSuggestion(for: lead))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedLead = lead }

            HStack(spacing: EBPSpacing.sm) {
                primaryFollowUpButton(for: lead)
                Button { selectedLead = lead } label: {
                    Text("Open")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EBPSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: EBPRadius.md)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contextMenu {
            ForEach(CRMLeadStage.allCases) { s in
                if s.rawValue != lead.status {
                    Button { moveLead(lead, to: s) } label: {
                        Label("Move to \(s.label)", systemImage: "arrow.right.circle")
                    }
                }
            }
            Divider()
            Button { convertLeadToClient(lead) } label: {
                Label("Convert to Client", systemImage: "person.crop.circle.badge.checkmark")
            }
            Divider()
            Button(role: .destructive) {
                modelContext.delete(lead)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func filteredLeads(for stage: CRMLeadStage) -> [Lead] {
        let stageLeads = allLeads.filter { $0.status == stage.rawValue }
        if searchText.isEmpty { return stageLeads }
        let lower = searchText.lowercased()
        return stageLeads.filter {
            $0.displayName.lowercased().contains(lower) ||
            $0.company.lowercased().contains(lower) ||
            $0.email.lowercased().contains(lower) ||
            $0.phone.lowercased().contains(lower)
        }
    }

    private func followUpSuggestion(for lead: Lead) -> String {
        EpoxyAIWorkflowAdvisor.nextBestAction(for: lead)
    }

    private func moveLead(_ lead: Lead, to stage: CRMLeadStage) {
        lead.status = stage.rawValue
        if stage == .won { lead.convertedAt = Date() }
        try? modelContext.save()
    }

    private func convertLeadToClient(_ lead: Lead) {
        let client = Client()
        client.firstName = lead.firstName
        client.lastName = lead.lastName
        client.email = lead.email
        client.phone = lead.phone
        client.company = lead.company
        client.address = lead.address
        client.clientType = "residential"
        modelContext.insert(client)
        lead.status = "WON"
        lead.convertedAt = Date()
        try? modelContext.save()
    }

    private func completeFollowUp(_ lead: Lead) {
        AppHaptics.trigger(.medium)
        let previousStatus = lead.status
        switch lead.status {
        case "NEW": lead.status = "CONTACTED"
        case "CONTACTED": lead.status = "SITE_VISIT"
        case "SITE_VISIT": lead.status = "BID_SENT"
        default: break
        }
        lead.followUpDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())
        try? modelContext.save()
        if previousStatus == "SITE_VISIT" || lead.status == "BID_SENT" {
            segment = .bids
        }
    }

    private func snoozeFollowUp(_ lead: Lead) {
        AppHaptics.trigger(.light)
        let base = lead.followUpDate ?? Date()
        lead.followUpDate = Calendar.current.date(byAdding: .day, value: 1, to: base)
        try? modelContext.save()
    }

    private func primaryFollowUpButton(for lead: Lead) -> some View {
        Group {
            if let url = telURL(for: lead.phone) {
                Button { openURL(url) } label: {
                    Label("Call", systemImage: "phone.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
                .buttonStyle(.plain)
            } else if let url = emailURL(for: lead.email) {
                Button { openURL(url) } label: {
                    Label("Email", systemImage: "envelope.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
                .buttonStyle(.plain)
            } else {
                Button { selectedLead = lead } label: {
                    Label("Review", systemImage: "arrow.forward")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(EBPColor.warning, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func telURL(for phone: String) -> URL? {
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    private func emailURL(for email: String) -> URL? {
        guard !email.isEmpty else { return nil }
        return URL(string: "mailto:\(email)")
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}
