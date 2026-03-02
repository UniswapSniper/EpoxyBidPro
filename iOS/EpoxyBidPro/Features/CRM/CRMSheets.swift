import SwiftUI
import SwiftData

// ─── Add Lead Sheet ──────────────────────────────────────────────────────────

struct AddLeadSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var company = ""
    @State private var address = ""
    @State private var source = "REFERRAL"
    @State private var estimatedValue = ""
    @State private var notes = ""
    @State private var followUpDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var hasFollowUp = true

    private let sources = ["REFERRAL", "GOOGLE", "YELP", "FACEBOOK", "DOOR_HANGER", "WEBSITE", "MANUAL"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Info") {
                    TextField("First Name", text: $firstName)
                        .textInputAutocapitalization(.words)
                    TextField("Last Name", text: $lastName)
                        .textInputAutocapitalization(.words)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Company (optional)", text: $company)
                        .textInputAutocapitalization(.words)
                }

                Section("Project Details") {
                    TextField("Address", text: $address)
                        .textInputAutocapitalization(.words)
                    TextField("Estimated Value ($)", text: $estimatedValue)
                        .keyboardType(.decimalPad)
                    Picker("Source", selection: $source) {
                        ForEach(sources, id: \.self) { s in
                            Text(s.replacingOccurrences(of: "_", with: " ").capitalized).tag(s)
                        }
                    }
                }

                Section("Follow-Up") {
                    Toggle("Schedule Follow-Up", isOn: $hasFollowUp)
                    if hasFollowUp {
                        DatePicker("Follow-Up Date", selection: $followUpDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }

                Section {
                    Button {
                        saveLead()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Create Lead", systemImage: "person.badge.plus")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(firstName.isEmpty && lastName.isEmpty)
                }
            }
            .navigationTitle("New Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveLead() {
        let lead = Lead()
        lead.firstName = firstName
        lead.lastName = lastName
        lead.email = email
        lead.phone = phone
        lead.company = company
        lead.address = address
        lead.source = source
        lead.estimatedValue = Double(estimatedValue) ?? 0
        lead.notes = notes
        if hasFollowUp {
            lead.followUpAt = followUpDate
        }
        modelContext.insert(lead)
        try? modelContext.save()
        dismiss()
    }
}

// ─── Add Client Sheet ────────────────────────────────────────────────────────

struct AddClientSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var company = ""
    @State private var address = ""
    @State private var clientType = "residential"

    private let types = ["residential", "commercial", "industrial"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Info") {
                    TextField("First Name", text: $firstName)
                        .textInputAutocapitalization(.words)
                    TextField("Last Name", text: $lastName)
                        .textInputAutocapitalization(.words)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Company") {
                    TextField("Company Name", text: $company)
                        .textInputAutocapitalization(.words)
                    Picker("Client Type", selection: $clientType) {
                        ForEach(types, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }

                Section("Address") {
                    TextField("Full Address", text: $address)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Button {
                        saveClient()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Create Client", systemImage: "person.crop.circle.badge.plus")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(firstName.isEmpty && lastName.isEmpty)
                }
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveClient() {
        let client = Client()
        client.firstName = firstName
        client.lastName = lastName
        client.email = email
        client.phone = phone
        client.company = company
        client.address = address
        client.clientType = clientType
        modelContext.insert(client)
        try? modelContext.save()
        dismiss()
    }
}

// ─── Lead Detail Sheet ───────────────────────────────────────────────────────

struct LeadDetailSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var lead: Lead

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    LabeledContent("Name", value: lead.displayName)
                    if !lead.email.isEmpty {
                        LabeledContent("Email", value: lead.email)
                    }
                    if !lead.phone.isEmpty {
                        LabeledContent("Phone", value: lead.phone)
                    }
                    if !lead.company.isEmpty {
                        LabeledContent("Company", value: lead.company)
                    }
                    if !lead.address.isEmpty {
                        LabeledContent("Address", value: lead.address)
                    }
                }

                Section("Lead Info") {
                    Picker("Status", selection: $lead.status) {
                        ForEach(CRMLeadStage.allCases) { stage in
                            Text(stage.label).tag(stage.rawValue)
                        }
                    }
                    LabeledContent("Source", value: lead.source.replacingOccurrences(of: "_", with: " ").capitalized)
                    LabeledContent("Est. Value", value: lead.estimatedValue > 0 ? "$\(Int(lead.estimatedValue))" : "—")
                    LabeledContent("Created", value: lead.createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Follow-Up") {
                    if let date = lead.followUpAt {
                        LabeledContent("Scheduled") {
                            HStack {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                if date < Date() {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(EBPColor.danger)
                                }
                            }
                        }
                    }
                    DatePicker(
                        "Set Follow-Up",
                        selection: Binding(
                            get: { lead.followUpAt ?? Date() },
                            set: { lead.followUpAt = $0 }
                        ),
                        displayedComponents: .date
                    )
                }

                Section("Notes") {
                    TextEditor(text: $lead.notes)
                        .frame(minHeight: 80)
                }

                if lead.status == "LOST" {
                    Section("Lost Reason") {
                        TextField("Why was this lead lost?", text: $lead.lostReason)
                    }
                }
            }
            .navigationTitle("Lead Details")
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
}

// ─── Client Detail Sheet ─────────────────────────────────────────────────────

struct ClientDetailSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var client: Client

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: EBPSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(EBPColor.primaryGradient)
                                .frame(width: 56, height: 56)
                            Text(String(client.displayName.prefix(1)).uppercased())
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(client.displayName)
                                .font(.headline)
                            if !client.company.isEmpty {
                                Text(client.company)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            EBPPillTag(text: client.clientType.capitalized, color: EBPColor.primary)
                        }
                    }
                    .padding(.vertical, EBPSpacing.xs)
                }

                Section("Contact") {
                    if !client.email.isEmpty {
                        Label(client.email, systemImage: "envelope")
                    }
                    if !client.phone.isEmpty {
                        Label(client.phone, systemImage: "phone")
                    }
                    if !client.address.isEmpty {
                        Label(client.address, systemImage: "mappin")
                    }
                }

                Section("History") {
                    let bidCount = client.bids.count
                    LabeledContent("Bids", value: "\(bidCount)")
                    let totalValue = client.bids.reduce(Decimal(0)) { $0 + $1.totalPrice }
                    LabeledContent("Total Value") {
                        Text(totalValue, format: .currency(code: "USD"))
                    }
                    let signedBids = client.bids.filter { $0.status == "SIGNED" }.count
                    LabeledContent("Signed Bids", value: "\(signedBids)")
                    LabeledContent("Client Since") {
                        Text(client.createdAt.formatted(date: .abbreviated, time: .omitted))
                    }
                }

                if !client.notes.isEmpty {
                    Section("Notes") {
                        Text(client.notes)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Client Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
