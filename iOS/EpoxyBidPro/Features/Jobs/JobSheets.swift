import SwiftUI
import SwiftData

// ─── Add Job Sheet ───────────────────────────────────────────────────────────

struct AddJobSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Client.firstName) private var clients: [Client]
    @Query(filter: #Predicate<Bid> { $0.status == "SIGNED" }) private var signedBids: [Bid]

    @State private var title = ""
    @State private var coatingSystem = ""
    @State private var address = ""
    @State private var totalSqFt = ""
    @State private var scheduledDate = Date()
    @State private var crewInput = ""
    @State private var selectedClient: Client? = nil
    @State private var selectedBid: Bid? = nil
    @State private var createFromBid = false

    var body: some View {
        NavigationStack {
            Form {
                // Create from bid
                if !signedBids.isEmpty {
                    Section {
                        Toggle("Create from Signed Bid", isOn: $createFromBid)
                            .tint(EBPColor.primary)

                        if createFromBid {
                            Picker("Select Bid", selection: $selectedBid) {
                                Text("Select a bid…").tag(nil as Bid?)
                                ForEach(signedBids) { bid in
                                    Text("\(bid.bidNumber) — \(bid.title)").tag(bid as Bid?)
                                }
                            }
                        }
                    }
                }

                Section("Job Details") {
                    TextField("Job Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Coating System", text: $coatingSystem)
                        .textInputAutocapitalization(.words)
                    TextField("Address", text: $address)
                        .textInputAutocapitalization(.words)
                    TextField("Square Footage", text: $totalSqFt)
                        .keyboardType(.numberPad)
                }

                Section("Client") {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(nil as Client?)
                        ForEach(clients) { client in
                            Text(client.displayName).tag(client as Client?)
                        }
                    }
                }

                Section("Schedule") {
                    DatePicker("Scheduled Date", selection: $scheduledDate, displayedComponents: [.date])
                }

                Section("Crew") {
                    TextField("Crew (comma-separated names)", text: $crewInput)
                        .textInputAutocapitalization(.words)
                    Text("e.g. Maria, Devon, Chris")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        saveJob()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Create Job", systemImage: "hammer.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(title.isEmpty && selectedBid == nil)
                }
            }
            .navigationTitle("New Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedBid) { _, bid in
                if let bid {
                    title = bid.title
                    coatingSystem = bid.coatingSystem
                    totalSqFt = "\(Int(bid.totalSqFt))"
                    selectedClient = bid.client
                    address = bid.client?.address ?? ""
                }
            }
        }
    }

    private func saveJob() {
        let job = Job()
        job.jobNumber = "JOB-\(Int.random(in: 10001...99999))"
        job.title = title
        job.coatingSystem = coatingSystem
        job.address = address
        job.totalSqFt = Double(totalSqFt) ?? 0
        job.scheduledDate = scheduledDate
        job.client = selectedClient
        job.bid = selectedBid

        if let bid = selectedBid {
            job.revenue = bid.totalPrice
        }

        // Parse crew
        job.assignedCrew = crewInput
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Default checklist
        let defaultItems = [
            "Surface prep & grinding",
            "Crack repair & patching",
            "Primer coat",
            "Base coat application",
            "Flake / broadcast",
            "Topcoat / sealer",
            "Final inspection",
            "Cleanup & walkthrough",
        ]
        for (idx, title) in defaultItems.enumerated() {
            let item = JobChecklistItem()
            item.title = title
            item.sortOrder = idx
            job.checklistItems.append(item)
            modelContext.insert(item)
        }

        modelContext.insert(job)
        try? modelContext.save()
        dismiss()
    }
}

// ─── Job Detail Sheet ────────────────────────────────────────────────────────

struct JobDetailSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var job: Job

    @State private var showInvoiceCreation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                    // ── Hero ──────────────────────────────────────────────
                    jobHero
                    
                    // ── Status Control ────────────────────────────────────
                    statusControl

                    // ── Crew ──────────────────────────────────────────────
                    crewSection

                    // ── Checklist ─────────────────────────────────────────
                    checklistSection

                    // ── Details ───────────────────────────────────────────
                    detailsSection

                    // ── Notes ─────────────────────────────────────────────
                    notesSection

                    // ── Actions ───────────────────────────────────────────
                    actionsSection
                }
                .padding(EBPSpacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(job.title.isEmpty ? job.jobNumber : job.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var jobHero: some View {
        VStack(spacing: EBPSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.jobNumber)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor)
                    Text(job.title.isEmpty ? "Untitled Job" : job.title)
                        .font(.title3.bold())
                    if let client = job.client {
                        Text(client.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                }
            }

            if !job.address.isEmpty {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(EBPColor.primary)
                    Text(job.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
    }

    // MARK: - Status Control

    private var statusControl: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text("Status")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EBPSpacing.xs) {
                    ForEach(["SCHEDULED", "IN_PROGRESS", "PUNCH_LIST", "COMPLETE", "INVOICED"], id: \.self) { status in
                        Button {
                            withAnimation {
                                job.status = status
                                if status == "IN_PROGRESS" { job.startedAt = Date() }
                                if status == "COMPLETE" { job.completedAt = Date() }
                                try? modelContext.save()
                            }
                        } label: {
                            Text(statusLabel(status))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .foregroundStyle(job.status == status ? .white : colorForStatus(status))
                                .background(
                                    job.status == status
                                        ? AnyShapeStyle(colorForStatus(status))
                                        : AnyShapeStyle(colorForStatus(status).opacity(0.10)),
                                    in: Capsule()
                                )
                        }
                    }
                }
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Crew

    private var crewSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(EBPColor.primary)
                Text("Crew")
                    .font(.headline)
                Spacer()
                Text("\(job.assignedCrew.count) member\(job.assignedCrew.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if job.assignedCrew.isEmpty {
                Text("No crew assigned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(job.assignedCrew, id: \.self) { name in
                    HStack(spacing: EBPSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(EBPColor.primary.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Text(String(name.prefix(1)).uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(EBPColor.primary)
                        }
                        Text(name)
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            let items = job.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder })
            let done = items.filter { $0.isComplete }.count

            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(EBPColor.primary)
                Text("Checklist")
                    .font(.headline)
                Spacer()
                Text("\(done)/\(items.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(done == items.count ? EBPColor.success : .secondary)
            }

            if !items.isEmpty {
                ProgressView(value: Double(done), total: Double(items.count))
                    .tint(done == items.count ? EBPColor.success : EBPColor.primary)
            }

            ForEach(items) { item in
                Button {
                    withAnimation(EBPAnimation.snappy) {
                        item.isComplete.toggle()
                        item.completedAt = item.isComplete ? Date() : nil
                        try? modelContext.save()
                    }
                } label: {
                    HStack(spacing: EBPSpacing.sm) {
                        Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(item.isComplete ? EBPColor.success : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline)
                                .foregroundStyle(item.isComplete ? .secondary : .primary)
                                .strikethrough(item.isComplete)

                            if let date = item.completedAt {
                                Text("Done \(date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if !item.photoUrl.isEmpty {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(EBPColor.primary)
                Text("Details")
                    .font(.headline)
            }

            Group {
                detailRow("Coating", job.coatingSystem.isEmpty ? "—" : job.coatingSystem)
                detailRow("Area", job.totalSqFt > 0 ? "\(Int(job.totalSqFt)) sq ft" : "—")
                detailRow("Scheduled", job.scheduledDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                if let started = job.startedAt {
                    detailRow("Started", started.formatted(date: .abbreviated, time: .shortened))
                }
                if let completed = job.completedAt {
                    detailRow("Completed", completed.formatted(date: .abbreviated, time: .shortened))
                }
                if job.revenue > 0 {
                    detailRow("Revenue", job.revenue.formatted(.currency(code: "USD")))
                }
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(EBPColor.primary)
                Text("Notes")
                    .font(.headline)
            }
            TextEditor(text: $job.notes)
                .frame(minHeight: 60)
                .font(.subheadline)
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: EBPSpacing.sm) {
            if job.status == "COMPLETE" {
                EBPButton(title: "Create Invoice", icon: "dollarsign.circle", style: .primary) {
                    showInvoiceCreation = true
                }
            }

            if job.status != "COMPLETE" && job.status != "INVOICED" && job.status != "PAID" {
                EBPButton(title: "Mark Complete & Create Invoice", icon: "checkmark.circle.fill", style: .primary) {
                    job.status = "COMPLETE"
                    job.completedAt = Date()
                    try? modelContext.save()
                    showInvoiceCreation = true
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        colorForStatus(job.status)
    }

    private var statusIcon: String {
        switch job.status {
        case "SCHEDULED":   return "calendar.badge.clock"
        case "IN_PROGRESS": return "hammer.fill"
        case "PUNCH_LIST":  return "list.bullet.clipboard"
        case "COMPLETE":    return "checkmark.seal.fill"
        case "INVOICED":    return "dollarsign.circle.fill"
        case "PAID":        return "banknote.fill"
        default:            return "questionmark.circle"
        }
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "SCHEDULED":   return .blue
        case "IN_PROGRESS": return EBPColor.primary
        case "PUNCH_LIST":  return .orange
        case "COMPLETE":    return EBPColor.success
        case "INVOICED":    return .purple
        case "PAID":        return .mint
        default:            return .secondary
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "SCHEDULED":   return "Scheduled"
        case "IN_PROGRESS": return "In Progress"
        case "PUNCH_LIST":  return "Punch List"
        case "COMPLETE":    return "Complete"
        case "INVOICED":    return "Invoiced"
        case "PAID":        return "Paid"
        default:            return status.capitalized
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
        }
    }
}

