import SwiftUI
import SwiftData

// ─── TimeTrackingView ─────────────────────────────────────────────────────────
// Full time-tracking screen for a single job.
// Shows active clock-in entries, historical log, and per-member hour totals.

struct TimeTrackingView: View {

    // MARK: - Inputs

    let job: Job

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Data

    @Query private var allEntries: [JobTimeEntry]
    private var entries: [JobTimeEntry] {
        allEntries.filter { $0.jobId == job.id }.sorted { $0.clockedIn > $1.clockedIn }
    }
    private var activeEntries: [JobTimeEntry] { entries.filter { $0.isActive } }
    private var completedEntries: [JobTimeEntry] { entries.filter { !$0.isActive } }

    // MARK: - State

    @State private var crewName = ""
    @State private var showAddEntry = false
    @State private var clockInNote = ""
    @State private var manualClockIn = Date()
    @State private var manualClockOut = Date()
    @State private var isManualEntry = false
    @State private var selectedEntry: JobTimeEntry? = nil

    // MARK: - Computed

    private var totalHours: Double {
        entries.reduce(0) { $0 + $1.durationHours }
    }

    private var crewHourSummary: [(name: String, hours: Double)] {
        let names = Set(entries.map { $0.crewMember }).sorted()
        return names.map { name in
            let hours = entries.filter { $0.crewMember == name }.reduce(0) { $0 + $1.durationHours }
            return (name: name, hours: hours)
        }.sorted { $0.hours > $1.hours }
    }

    private var laborCostEstimate: Double {
        totalHours * 45.0  // default $45/hr; can be made configurable
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: EBPSpacing.lg) {
                    summaryBanner
                    if !activeEntries.isEmpty { activeClockInsSection }
                    crewSummarySection
                    timeLogSection
                }
                .padding(EBPSpacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Time Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAddEntry = true
                    } label: {
                        Label("Clock In", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddEntry) {
                clockInSheet
            }
        }
    }

    // MARK: - Summary Banner

    private var summaryBanner: some View {
        HStack(spacing: 0) {
            summaryCell(
                value: String(format: "%.1f", totalHours),
                label: "Total Hours",
                color: EBPColor.primary
            )
            Divider().frame(height: 44)
            summaryCell(
                value: "$\(Int(laborCostEstimate))",
                label: "Labor Est.",
                color: .green
            )
            Divider().frame(height: 44)
            summaryCell(
                value: "\(activeEntries.count)",
                label: "Clocked In",
                color: activeEntries.isEmpty ? .secondary : EBPColor.accent
            )
            Divider().frame(height: 44)
            summaryCell(
                value: "\(completedEntries.count)",
                label: "Completed",
                color: .secondary
            )
        }
        .padding(.vertical, EBPSpacing.sm)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EBPSpacing.xs)
    }

    // MARK: - Active Clock-Ins

    private var activeClockInsSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Label("Currently Clocked In", systemImage: "timer")
                .font(.headline)
                .foregroundStyle(EBPColor.accent)

            ForEach(activeEntries) { entry in
                activeEntryRow(entry)
            }
        }
    }

    private func activeEntryRow(_ entry: JobTimeEntry) -> some View {
        HStack(spacing: EBPSpacing.md) {
            ZStack {
                Circle()
                    .fill(EBPColor.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(entry.crewMember.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(EBPColor.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.crewMember.isEmpty ? "Unknown" : entry.crewMember)
                    .font(.subheadline.weight(.semibold))
                Text("Since \(entry.clockedIn.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Live timer display
            TimelineView(.periodic(from: Date(), by: 60)) { _ in
                Text(String(format: "%.1fh", entry.durationHours))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EBPColor.accent)
                    .monospacedDigit()
            }

            Button {
                clockOut(entry)
            } label: {
                Text("Clock Out")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(EBPColor.accent.opacity(0.12), in: Capsule())
                    .foregroundStyle(EBPColor.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: EBPRadius.md)
                .stroke(EBPColor.accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Crew Hour Summary

    private var crewSummarySection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text("Crew Summary")
                .font(.headline)

            if crewHourSummary.isEmpty {
                Text("No time entries yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(EBPSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            } else {
                let maxHours = crewHourSummary.first?.hours ?? 1
                VStack(spacing: 0) {
                    ForEach(crewHourSummary, id: \.name) { row in
                        VStack(spacing: 6) {
                            HStack {
                                Text(row.name.isEmpty ? "Unknown" : row.name)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(String(format: "%.1f hrs", row.hours))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(EBPColor.primary)
                                Text("· $\(Int(row.hours * 45))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                                    let pct = maxHours > 0 ? CGFloat(row.hours / maxHours) : 0
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(EBPColor.primary.gradient)
                                        .frame(width: geo.size.width * pct)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(EBPSpacing.md)
                        if row.name != crewHourSummary.last?.name { Divider().padding(.leading, EBPSpacing.md) }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            }
        }
    }

    // MARK: - Time Log

    private var timeLogSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text("Time Log")
                .font(.headline)

            if completedEntries.isEmpty {
                Text("Completed entries will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(EBPSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            } else {
                VStack(spacing: 0) {
                    ForEach(completedEntries) { entry in
                        completedEntryRow(entry)
                        if entry.id != completedEntries.last?.id {
                            Divider().padding(.leading, EBPSpacing.md)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            }
        }
    }

    private func completedEntryRow(_ entry: JobTimeEntry) -> some View {
        HStack(spacing: EBPSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.crewMember.isEmpty ? "Unknown" : entry.crewMember)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text(entry.clockedIn.formatted(date: .abbreviated, time: .shortened))
                    Text("→")
                    Text(entry.clockedOut?.formatted(date: .omitted, time: .shortened) ?? "—")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(String(format: "%.1fh", entry.durationHours))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(EBPSpacing.md)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                modelContext.delete(entry)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Clock-In Sheet

    private var clockInSheet: some View {
        NavigationStack {
            Form {
                Section("Crew Member") {
                    if job.assignedCrew.isEmpty {
                        TextField("Name", text: $crewName)
                    } else {
                        Picker("Select Crew", selection: $crewName) {
                            Text("Select…").tag("")
                            ForEach(job.assignedCrew, id: \.self) { name in
                                Text(name).tag(name)
                            }
                            Text("Other…").tag("_other")
                        }
                        if crewName == "_other" {
                            TextField("Enter name", text: $crewName)
                        }
                    }
                }

                Section("Entry Type") {
                    Toggle("Manual Entry", isOn: $isManualEntry)
                        .tint(EBPColor.primary)
                }

                if isManualEntry {
                    Section("Time") {
                        DatePicker("Clock In", selection: $manualClockIn, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("Clock Out", selection: $manualClockOut, in: manualClockIn..., displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Notes") {
                    TextField("Optional note", text: $clockInNote)
                }

                Section {
                    Button {
                        addEntry()
                        showAddEntry = false
                    } label: {
                        HStack {
                            Spacer()
                            Label(isManualEntry ? "Add Entry" : "Clock In Now", systemImage: isManualEntry ? "plus.circle" : "timer")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(crewName.isEmpty || crewName == "_other")
                    .tint(EBPColor.primary)
                }
            }
            .navigationTitle(isManualEntry ? "Add Time Entry" : "Clock In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddEntry = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func addEntry() {
        let entry = JobTimeEntry(
            crewMember: crewName == "_other" ? "" : crewName,
            clockedIn: isManualEntry ? manualClockIn : Date(),
            clockedOut: isManualEntry ? manualClockOut : nil,
            notes: clockInNote,
            jobId: job.id
        )
        modelContext.insert(entry)
        try? modelContext.save()

        // Reset
        crewName = ""
        clockInNote = ""
        isManualEntry = false
        manualClockIn = Date()
        manualClockOut = Date()
    }

    private func clockOut(_ entry: JobTimeEntry) {
        entry.clockedOut = Date()
        try? modelContext.save()
    }
}
