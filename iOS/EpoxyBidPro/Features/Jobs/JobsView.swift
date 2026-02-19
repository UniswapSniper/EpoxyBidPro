import SwiftUI

struct JobsView: View {
    @State private var selectedSection: JobsSection = .dashboard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: EBPSpacing.md) {
                    Picker("Jobs Section", selection: $selectedSection) {
                        ForEach(JobsSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    sectionView
                }
                .padding(EBPSpacing.md)
            }
            .navigationTitle("Jobs")
        }
    }

    @ViewBuilder
    private var sectionView: some View {
        switch selectedSection {
        case .dashboard:
            JobDashboardSection()
        case .scheduling:
            JobSchedulingSection()
        case .detail:
            JobDetailSection()
        case .crew:
            CrewManagementSection()
        case .materials:
            MaterialsEquipmentSection()
        }
    }
}

private enum JobsSection: String, CaseIterable, Identifiable {
    case dashboard
    case scheduling
    case detail
    case crew
    case materials

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .scheduling: "Schedule"
        case .detail: "Job Detail"
        case .crew: "Crew"
        case .materials: "Materials"
        }
    }
}

private struct JobDashboardSection: View {
    private let statusFlow = "Scheduled → In Progress → Punch List → Complete → Invoiced → Paid"

    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.md) {
            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Status Pipeline")
                        .font(.headline)
                    Text(statusFlow)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Filters")
                        .font(.headline)
                    Text("Date: This Week • Status: In Progress • Crew: Team A • Region: North")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(JobCardPreview.samples) { job in
                EBPCard {
                    VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        HStack {
                            Text(job.client)
                                .font(.headline)
                            Spacer()
                            EBPBadge(text: job.status.displayText, color: job.status.color)
                        }

                        Text(job.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(job.dateText) • \(job.coatingSystem) • \(Int(job.squareFootage)) sq ft")
                            .font(.footnote)

                        Text("Crew: \(job.crew.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct JobSchedulingSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.md) {
            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Calendar Views")
                        .font(.headline)
                    Text("Monthly • Weekly • Daily")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Drag and drop is enabled through the native calendar interactions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Crew Availability")
                        .font(.headline)
                    ForEach(CrewAvailability.samples) { availability in
                        HStack {
                            Text(availability.member)
                            Spacer()
                            EBPBadge(text: availability.status, color: availability.isFree ? EBPColor.success : EBPColor.danger)
                        }
                        .font(.subheadline)
                    }
                }
            }

            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Travel & Calendar Sync")
                        .font(.headline)
                    Text("Travel estimate: 28 min between first two jobs (MapKit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Connected: iCal, Google Calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("No scheduling conflicts detected for selected day.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct JobDetailSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.md) {
            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Client & Property")
                        .font(.headline)
                    Text("Acme Logistics • 42 Industrial Way, Phoenix, AZ")
                        .font(.subheadline)
                    Text("Tap to open navigation in Maps")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Scope & Crew")
                        .font(.headline)
                    Text("System: Moisture Vapor Barrier + Flake + Polyaspartic Topcoat")
                        .font(.subheadline)
                    Text("Crew: Maria, Devon, Chris")
                        .font(.subheadline)
                }
            }

            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Checklist")
                        .font(.headline)
                    ForEach(JobChecklistItem.samples) { item in
                        HStack {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isDone ? EBPColor.success : .secondary)
                            Text(item.title)
                                .font(.subheadline)
                            Spacer()
                            Text("Photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            EBPButton(title: "Mark Complete & Create Invoice", style: .primary) {}
        }
    }
}

private struct CrewManagementSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.md) {
            ForEach(CrewProfile.samples) { profile in
                EBPCard {
                    VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        HStack {
                            Text(profile.name)
                                .font(.headline)
                            Spacer()
                            Text(profile.role)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text(profile.phone)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Hourly: \(profile.hourlyRate)")
                            Spacer()
                            Text("Today: \(profile.timeLog)")
                        }
                        .font(.footnote)
                    }
                }
            }

            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Crew Reports")
                        .font(.headline)
                    Text("Each profile tracks completed jobs, time on site, and overtime trends.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct MaterialsEquipmentSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.md) {
            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Auto-Generated Materials")
                        .font(.headline)
                    ForEach(MaterialLine.samples) { line in
                        HStack {
                            Text(line.name)
                            Spacer()
                            EBPBadge(text: line.status, color: line.statusColor)
                        }
                        .font(.subheadline)
                    }
                }
            }

            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Equipment Checklist")
                        .font(.headline)
                    Text("• Grinder with HEPA vacuum\n• Crack chase tools\n• Mixing station\n• Spiked shoes and PPE")
                        .font(.subheadline)
                }
            }

            EBPCard {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Supplier Contacts")
                        .font(.headline)
                    Text("Southwest Coatings: (602) 555-0147")
                        .font(.subheadline)
                    Text("Desert Equipment Rental: (602) 555-0193")
                        .font(.subheadline)
                }
            }
        }
    }
}

private enum JobStatus {
    case scheduled
    case inProgress
    case punchList
    case complete
    case invoiced
    case paid

    var displayText: String {
        switch self {
        case .scheduled: "Scheduled"
        case .inProgress: "In Progress"
        case .punchList: "Punch List"
        case .complete: "Complete"
        case .invoiced: "Invoiced"
        case .paid: "Paid"
        }
    }

    var color: Color {
        switch self {
        case .scheduled: EBPColor.secondary
        case .inProgress: EBPColor.primary
        case .punchList: .orange
        case .complete: EBPColor.success
        case .invoiced: .purple
        case .paid: .mint
        }
    }
}

private struct JobCardPreview: Identifiable {
    let id = UUID()
    let client: String
    let address: String
    let dateText: String
    let coatingSystem: String
    let squareFootage: Double
    let crew: [String]
    let status: JobStatus

    static let samples: [JobCardPreview] = [
        JobCardPreview(client: "Baker Residence", address: "1278 Maple Dr, Tempe, AZ", dateText: "Tue, Nov 5", coatingSystem: "Full Flake", squareFootage: 610, crew: ["Maria", "Devon"], status: .scheduled),
        JobCardPreview(client: "Acme Logistics", address: "42 Industrial Way, Phoenix, AZ", dateText: "Wed, Nov 6", coatingSystem: "Quartz Broadcast", squareFootage: 4200, crew: ["Chris", "Leah", "Jordan"], status: .inProgress),
        JobCardPreview(client: "Harbor Auto", address: "912 Harbor St, Mesa, AZ", dateText: "Thu, Nov 7", coatingSystem: "Solid Color", squareFootage: 1800, crew: ["Devon", "Leah"], status: .punchList)
    ]
}

private struct CrewAvailability: Identifiable {
    let id = UUID()
    let member: String
    let status: String
    let isFree: Bool

    static let samples: [CrewAvailability] = [
        CrewAvailability(member: "Maria", status: "Available", isFree: true),
        CrewAvailability(member: "Devon", status: "Booked", isFree: false),
        CrewAvailability(member: "Chris", status: "Available", isFree: true)
    ]
}

private struct JobChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let isDone: Bool

    static let samples: [JobChecklistItem] = [
        JobChecklistItem(title: "Surface prep completed", isDone: true),
        JobChecklistItem(title: "Primer coat applied", isDone: true),
        JobChecklistItem(title: "Broadcast stage", isDone: false),
        JobChecklistItem(title: "Topcoat and final inspection", isDone: false),
        JobChecklistItem(title: "Cleanup", isDone: false)
    ]
}

private struct CrewProfile: Identifiable {
    let id = UUID()
    let name: String
    let phone: String
    let role: String
    let hourlyRate: String
    let timeLog: String

    static let samples: [CrewProfile] = [
        CrewProfile(name: "Maria Ortega", phone: "(602) 555-0172", role: "Crew Lead", hourlyRate: "$42/hr", timeLog: "6h 20m"),
        CrewProfile(name: "Devon Lee", phone: "(602) 555-0120", role: "Installer", hourlyRate: "$32/hr", timeLog: "5h 45m")
    ]
}

private struct MaterialLine: Identifiable {
    let id = UUID()
    let name: String
    let status: String

    var statusColor: Color {
        switch status {
        case "Purchased": EBPColor.success
        case "On-site": EBPColor.primary
        case "Used": .secondary
        default: .secondary
        }
    }

    static let samples: [MaterialLine] = [
        MaterialLine(name: "Moisture Vapor Barrier (10 gal)", status: "Purchased"),
        MaterialLine(name: "Flake Blend - Granite (6 boxes)", status: "On-site"),
        MaterialLine(name: "Polyaspartic Topcoat (8 gal)", status: "Used")
    ]
}
