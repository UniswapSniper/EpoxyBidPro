import SwiftUI
import SwiftData

// ─── JobsView ─────────────────────────────────────────────────────────────────
// Full jobs management with status pipeline, calendar, crew assignment,
// checklist-based workflow, and materials tracking.
// All data driven by SwiftData Job model.

struct JobsView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workflowRouter: WorkflowRouter
    @Query(sort: \Lead.createdAt, order: .reverse) private var workflowLeads: [Lead]
    @Query(sort: \Job.scheduledDate, order: .forward) private var allJobs: [Job]
    @Query(sort: \Bid.createdAt, order: .reverse) private var allBids: [Bid]
    @Query(sort: \Invoice.createdAt, order: .reverse) private var workflowInvoices: [Invoice]
    @Query(sort: \Measurement.scanDate, order: .reverse) private var workflowMeasurements: [Measurement]

    @State private var selectedFilter: JobStatusFilter = .all
    @State private var showAddJob = false
    @State private var selectedJob: Job? = nil
    @State private var calendarDate = Date()
    @State private var showOnlyAtRisk = false
    @State private var showCalendar = false
    @State private var showCrew = false

    enum JobStatusFilter: String, CaseIterable {
        case all         = "All"
        case scheduled   = "SCHEDULED"
        case inProgress  = "IN_PROGRESS"
        case punchList   = "PUNCH_LIST"
        case complete    = "COMPLETE"
        case invoiced    = "INVOICED"

        var label: String {
            switch self {
            case .all:        return "All"
            case .scheduled:  return "Scheduled"
            case .inProgress: return "In Progress"
            case .punchList:  return "Punch List"
            case .complete:   return "Complete"
            case .invoiced:   return "Invoiced"
            }
        }

        var color: Color {
            if self == .all { return .white }
            return WorkflowStatusPalette.job(rawValue)
        }
    }

    private var filteredJobs: [Job] {
        let base: [Job]
        if selectedFilter == .all {
            base = Array(allJobs)
        } else {
            base = allJobs.filter { $0.status == selectedFilter.rawValue }
        }

        if showOnlyAtRisk {
            return base.filter { isAtRisk($0) }
        }

        return base
    }

    private var readySignedBids: [Bid] {
        let linkedBidIds = Set(allJobs.compactMap { $0.bid?.id })
        return allBids.filter { $0.status == "SIGNED" && !linkedBidIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EBPDynamicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        boardView
                        Spacer(minLength: 120)
                    }
                }
            }
            .navigationTitle("Jobs")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showCalendar = true } label: {
                            Image(systemName: "calendar")
                                .foregroundStyle(.white)
                        }
                        Button { showCrew = true } label: {
                            Image(systemName: "person.3")
                                .foregroundStyle(.white)
                        }
                        Button { showAddJob = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(EBPColor.accent)
                                .ebpNeonGlow(radius: 4, intensity: 0.5)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddJob) {
                AddJobSheet()
            }
            .sheet(item: $selectedJob) { job in
                JobDetailSheet(job: job)
            }
            .sheet(isPresented: $showCalendar) {
                NavigationStack {
                    calendarView
                        .navigationTitle("Calendar")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showCalendar = false }
                                    .fontWeight(.semibold)
                            }
                        }
                }
            }
            .sheet(isPresented: $showCrew) {
                NavigationStack {
                    ZStack {
                        EBPDynamicBackground()
                        ScrollView { crewView }
                    }
                    .navigationTitle("Crew")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showCrew = false }
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Board View

    private var boardView: some View {
        VStack(spacing: 0) {
            executionCommandBar
            profitabilityBar

            // Status pipeline summary
            statusPipeline

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EBPSpacing.xs) {
                    ForEach(JobStatusFilter.allCases, id: \.rawValue) { filter in
                        let count = filter == .all ? allJobs.count : allJobs.filter({ $0.status == filter.rawValue }).count
                        FilterChip(
                            title: filter.label,
                            count: count,
                            isSelected: selectedFilter == filter,
                            action: {
                                withAnimation { selectedFilter = filter }
                            }
                        )
                    }
                }
                .padding(.horizontal, EBPSpacing.md)
                .padding(.vertical, EBPSpacing.sm)
            }

            // Job list
            if filteredJobs.isEmpty {
                EBPEmptyState(
                    icon: "hammer.fill",
                    title: "No Jobs",
                    subtitle: "Create a job from a signed bid to get started."
                )
                .padding(.top, EBPSpacing.xl)
                .padding(.horizontal, EBPSpacing.md)
            } else {
                LazyVStack(spacing: EBPSpacing.sm) {
                    ForEach(filteredJobs) { job in
                        jobCard(job)
                    }
                }
                .padding(EBPSpacing.md)
            }
        }
    }

    private var executionCommandBar: some View {
        HStack(spacing: EBPSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Execution Pipeline")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(readySignedBids.count) signed bid\(readySignedBids.count == 1 ? "" : "s") ready to schedule")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Button {
                createJobFromNextSignedBid()
            } label: {
                Label("Create Next Job", systemImage: "hammer.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.vertical, 10)
                    .background(readySignedBids.isEmpty ? Color.gray.opacity(0.5) : EBPColor.accent,
                                in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            }
            .buttonStyle(.plain)
            .disabled(readySignedBids.isEmpty)

            Button {
                withAnimation { showOnlyAtRisk.toggle() }
            } label: {
                Image(systemName: showOnlyAtRisk ? "exclamationmark.triangle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(showOnlyAtRisk ? EBPColor.warning : .white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: 0)
    }

    private var profitabilityBar: some View {
        let riskCount = allJobs.filter { isAtRisk($0) }.count
        let avgMargin = averageMarginPercent

        return HStack(spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.xs) {
                Image(systemName: riskCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.seal")
                    .foregroundStyle(riskCount > 0 ? EBPColor.warning : EBPColor.success)
                Text(riskCount > 0 ? "\(riskCount) at-risk job\(riskCount == 1 ? "" : "s")" : "No at-risk jobs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text("Avg margin \(avgMargin)%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(avgMargin < 25 ? EBPColor.warning : EBPColor.success)
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.vertical, EBPSpacing.sm)
        .background(Color.white.opacity(0.04))
    }

    private var statusPipeline: some View {
        let statuses: [(String, String, Color)] = [
            ("Scheduled", "\(allJobs.filter { $0.status == "SCHEDULED" }.count)", .blue),
            ("In Progress", "\(allJobs.filter { $0.status == "IN_PROGRESS" }.count)", EBPColor.accent),
            ("Punch List", "\(allJobs.filter { $0.status == "PUNCH_LIST" }.count)", .orange),
            ("Complete", "\(allJobs.filter { $0.status == "COMPLETE" }.count)", EBPColor.success),
            ("Invoiced", "\(allJobs.filter { $0.status == "INVOICED" }.count)", .purple),
        ]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(statuses, id: \.0) { name, count, color in
                    VStack(spacing: 4) {
                        Text(count)
                            .font(.title3.weight(.black))
                            .foregroundStyle(color)
                        Text(name)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 72)
                    .padding(.vertical, EBPSpacing.sm)

                    if name != "Invoiced" {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                }
            }
            .padding(.horizontal, EBPSpacing.md)
        }
        .ebpGlassmorphism(cornerRadius: 0)
    }

    private func jobCard(_ job: Job) -> some View {
        Button {
            selectedJob = job
        } label: {
            VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(job.title.isEmpty ? "Job #\(job.jobNumber)" : job.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let client = job.client {
                            Text(client.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    EBPBadge(text: statusLabel(job.status), color: statusColor(job.status))
                }

                HStack(spacing: EBPSpacing.md) {
                    Label(job.scheduledDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unscheduled",
                          systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !job.coatingSystem.isEmpty {
                        Text("•")
                            .foregroundStyle(.quaternary)
                        Text(job.coatingSystem)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if job.totalSqFt > 0 {
                        Text("•")
                            .foregroundStyle(.quaternary)
                        Text("\(Int(job.totalSqFt)) sf")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: EBPSpacing.xs) {
                    let margin = grossMarginPercent(for: job)
                    EBPBadge(
                        text: margin == nil ? "Margin —" : "Margin \(margin!)%",
                        color: marginColor(margin)
                    )

                    EBPBadge(
                        text: "Risk \(EpoxyAIWorkflowAdvisor.jobRiskScore(job))",
                        color: isAtRisk(job) ? EBPColor.warning : EBPColor.success
                    )

                    if isAtRisk(job) {
                        EBPBadge(text: "At Risk", color: EBPColor.warning)
                    }
                }

                // Checklist progress
                let total = job.checklistItems.count
                let done = job.checklistItems.filter { $0.isComplete }.count
                if total > 0 {
                    HStack(spacing: EBPSpacing.sm) {
                        ProgressView(value: Double(done), total: Double(total))
                            .tint(statusColor(job.status))

                        Text("\(done)/\(total)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Crew
                if !job.assignedCrew.isEmpty {
                    HStack(spacing: -6) {
                        ForEach(job.assignedCrew.prefix(4), id: \.self) { name in
                            ZStack {
                                Circle()
                                    .fill(EBPColor.primary.opacity(0.12))
                                    .frame(width: 24, height: 24)
                                Text(String(name.prefix(1)).uppercased())
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(EBPColor.primary)
                            }
                        }
                        if job.assignedCrew.count > 4 {
                            Text("+\(job.assignedCrew.count - 4)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                }
            }
            .padding(EBPSpacing.md)
            .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if job.status != "IN_PROGRESS" {
                Button { advanceStatus(job, to: "IN_PROGRESS") } label: {
                    Label("Start Job", systemImage: "play.fill")
                }
            }
            if job.status != "COMPLETE" {
                Button { advanceStatus(job, to: "COMPLETE") } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle")
                }
            }
            if job.status == "COMPLETE" {
                Button {
                    advanceStatus(job, to: "INVOICED")
                    workflowRouter.navigate(to: .payments, handoffMessage: "Job invoiced — review in Payments")
                } label: {
                    Label("Create Invoice", systemImage: "dollarsign.circle")
                }
            }
        }
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        VStack(spacing: 0) {
            DatePicker("", selection: $calendarDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(EBPColor.primary)
                .padding(.horizontal, EBPSpacing.md)

            Divider()

            let dayJobs = allJobs.filter {
                guard let d = $0.scheduledDate else { return false }
                return Calendar.current.isDate(d, inSameDayAs: calendarDate)
            }

            if dayJobs.isEmpty {
                EBPEmptyState(
                    icon: "calendar.badge.minus",
                    title: "No jobs on this date",
                    subtitle: "Pick a different day or create a job to populate the calendar."
                )
                .padding(.top, EBPSpacing.lg)
            } else {
                LazyVStack(spacing: EBPSpacing.sm) {
                    ForEach(dayJobs) { job in
                        jobCard(job)
                    }
                }
                .padding(EBPSpacing.md)
            }
        }
    }

    // MARK: - Crew View

    private var crewView: some View {
        VStack(spacing: EBPSpacing.md) {
            let crewNames = Set(allJobs.flatMap { $0.assignedCrew })

            if crewNames.isEmpty {
                EBPEmptyState(
                    icon: "person.3.fill",
                    title: "No Crew Members",
                    subtitle: "Assign crew members to jobs to see them here."
                )
                .padding(.top, EBPSpacing.xl)
            } else {
                ForEach(Array(crewNames).sorted(), id: \.self) { name in
                    crewMemberCard(name)
                }
            }
        }
        .padding(EBPSpacing.md)
    }

    private func crewMemberCard(_ name: String) -> some View {
        let memberJobs = allJobs.filter { $0.assignedCrew.contains(name) }
        let activeJobs = memberJobs.filter { ["SCHEDULED", "IN_PROGRESS"].contains($0.status) }

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.md) {
                ZStack {
                    Circle()
                        .fill(EBPColor.primaryGradient)
                        .frame(width: 44, height: 44)
                    Text(String(name.prefix(1)).uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                    Text("\(activeJobs.count) active • \(memberJobs.count) total jobs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                EBPBadge(
                    text: activeJobs.isEmpty ? "Available" : "Busy",
                    color: activeJobs.isEmpty ? EBPColor.success : EBPColor.warning
                )
            }

            if let nextJob = activeJobs.first {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(EBPColor.primary)
                    Text("Next: \(nextJob.title.isEmpty ? nextJob.jobNumber : nextJob.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let date = nextJob.scheduledDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
    }

    // MARK: - Helpers

    private func advanceStatus(_ job: Job, to status: String) {
        job.status = status
        if status == "IN_PROGRESS" { job.startedAt = Date() }
        if status == "COMPLETE" { job.completedAt = Date() }
        try? modelContext.save()
    }

    private func createJobFromNextSignedBid() {
        guard let bid = readySignedBids.first else { return }

        let nextIndex = allJobs.count + 1
        let generatedNumber = String(format: "J-%04d", nextIndex)

        let job = Job(
            jobNumber: generatedNumber,
            title: bid.title.isEmpty ? "Job from \(bid.bidNumber.isEmpty ? generatedNumber : bid.bidNumber)" : bid.title,
            status: "SCHEDULED",
            coatingSystem: bid.coatingSystem,
            scheduledDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            totalSqFt: bid.totalSqFt,
            address: bid.client?.address ?? "",
            revenue: bid.totalPrice,
            client: bid.client,
            bid: bid
        )

        modelContext.insert(job)
        try? modelContext.save()

        selectedSection = .board
        selectedFilter = .scheduled
        selectedJob = job
    }

    private func grossMarginPercent(for job: Job) -> Int? {
        guard job.revenue > 0 else { return nil }
        let margin = ((job.revenue - job.actualCost) / job.revenue) * 100
        return NSDecimalNumber(decimal: margin).intValue
    }

    private func marginColor(_ margin: Int?) -> Color {
        guard let margin else { return .secondary }
        if margin < 20 { return EBPColor.warning }
        if margin < 30 { return EBPColor.accent }
        return EBPColor.success
    }

    private func isAtRisk(_ job: Job) -> Bool {
        EpoxyAIWorkflowAdvisor.jobRiskScore(job) >= 60
    }

    private var averageMarginPercent: Int {
        let margins = allJobs.compactMap { grossMarginPercent(for: $0) }
        guard !margins.isEmpty else { return 0 }
        return Int(Double(margins.reduce(0, +)) / Double(margins.count))
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

    private func statusColor(_ status: String) -> Color {
        WorkflowStatusPalette.job(status)
    }
}
