import SwiftUI
import SwiftData

// ─── Step 1: Client Selection ────────────────────────────────────────────────

struct BidBuilderClientStep: View {

    @ObservedObject var vm: BidBuilderViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.firstName) private var clients: [Client]

    @State private var searchText = ""
    @State private var showNewClient = false

    private var filtered: [Client] {
        guard !searchText.isEmpty else { return Array(clients.prefix(20)) }
        let lower = searchText.lowercased()
        return clients.filter {
            $0.displayName.lowercased().contains(lower) ||
            $0.company.lowercased().contains(lower) ||
            $0.email.lowercased().contains(lower)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                // ── Header ─────────────────────────────────────────────────
                stepHeader(
                    icon: "person.fill",
                    title: NSLocalizedString("select.client", comment: ""),
                    subtitle: NSLocalizedString("select.client.subtitle", comment: "")
                )

                // ── Selected client card ───────────────────────────────────
                if let client = vm.selectedClient {
                    selectedClientCard(client)
                }

                // ── Search ─────────────────────────────────────────────────
                HStack(spacing: EBPSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(NSLocalizedString("search.clients", comment: ""), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(EBPSpacing.sm + 2)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                .ebpHPadding()

                // ── Client List ────────────────────────────────────────────
                if filtered.isEmpty {
                    VStack(spacing: EBPSpacing.sm) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("no.clients.found", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button(NSLocalizedString("create.new.client", comment: "")) {
                            showNewClient = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EBPColor.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EBPSpacing.xl)
                } else {
                    VStack(spacing: 0) {
                        ForEach(filtered) { client in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(EBPAnimation.snappy) {
                                    vm.selectedClient = (vm.selectedClient?.id == client.id) ? nil : client
                                }
                            } label: {
                                clientRow(client, isSelected: vm.selectedClient?.id == client.id)
                            }
                            .buttonStyle(.plain)

                            if client.id != filtered.last?.id {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                    .ebpShadowSubtle()
                    .ebpHPadding()
                }

                // ── Skip option ────────────────────────────────────────────
                if vm.selectedClient == nil {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("skip.client.hint", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .ebpHPadding()
                }
            }
            .padding(.vertical, EBPSpacing.md)
        }
        .sheet(isPresented: $showNewClient) {
            quickClientSheet
        }
    }

    // MARK: - Selected Client Card

    private func selectedClientCard(_ client: Client) -> some View {
        HStack(spacing: EBPSpacing.md) {
            ZStack {
                Circle()
                    .fill(EBPColor.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(client.displayName.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(EBPColor.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayName)
                    .font(.body.weight(.semibold))
                if !client.company.isEmpty {
                    Text(client.company)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(EBPColor.success)

            Button {
                withAnimation { vm.selectedClient = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.success.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: EBPRadius.md)
                .strokeBorder(EBPColor.success.opacity(0.25), lineWidth: 1.5)
        )
        .ebpHPadding()
    }

    // MARK: - Client Row

    private func clientRow(_ client: Client, isSelected: Bool) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            ZStack {
                Circle()
                    .fill(isSelected ? EBPColor.primary : Color(.systemGray5))
                    .frame(width: 36, height: 36)
                Text(String(client.displayName.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if !client.company.isEmpty {
                    Text(client.company)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            EBPPillTag(text: client.clientType.capitalized, color: .secondary)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(EBPColor.primary)
            }
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.vertical, 10)
        .background(isSelected ? EBPColor.primary.opacity(0.04) : Color.clear)
    }

    // MARK: - Quick Client Sheet

    @State private var newFirstName = ""
    @State private var newLastName = ""
    @State private var newEmail = ""
    @State private var newPhone = ""
    @State private var newCompany = ""

    private var quickClientSheet: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("contact.info", comment: "")) {
                    TextField(NSLocalizedString("first.name", comment: ""), text: $newFirstName)
                        .textInputAutocapitalization(.words)
                    TextField(NSLocalizedString("last.name", comment: ""), text: $newLastName)
                        .textInputAutocapitalization(.words)
                    TextField(NSLocalizedString("email", comment: ""), text: $newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField(NSLocalizedString("phone", comment: ""), text: $newPhone)
                        .keyboardType(.phonePad)
                }
                Section(NSLocalizedString("company", comment: "")) {
                    TextField(NSLocalizedString("company.name.optional", comment: ""), text: $newCompany)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    Button(NSLocalizedString("create.client", comment: "")) {
                        let client = Client()
                        client.firstName = newFirstName
                        client.lastName = newLastName
                        client.email = newEmail
                        client.phone = newPhone
                        client.company = newCompany
                        modelContext.insert(client)
                        try? modelContext.save()
                        vm.selectedClient = client
                        showNewClient = false
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(newFirstName.isEmpty && newLastName.isEmpty)
                }
            }
            .navigationTitle(NSLocalizedString("new.client", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) { showNewClient = false }
                }
            }
        }
    }
}

// ─── Step 2: Measurement ─────────────────────────────────────────────────────

struct BidBuilderMeasurementStep: View {

    @ObservedObject var vm: BidBuilderViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Measurement.scanDate, order: .reverse) private var measurements: [Measurement]

    @State private var mode: MeasurementMode = .scan
    @State private var showScanSheet = false

    enum MeasurementMode {
        case scan, manual
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                stepHeader(
                    icon: "ruler.fill",
                    title: "Floor Measurement",
                    subtitle: "Attach a LiDAR scan or enter dimensions manually."
                )

                // ── Mode Picker ───────────────────────────────────────────
                Picker("Mode", selection: $mode) {
                    Text(NSLocalizedString("lidar.scans", comment: "")).tag(MeasurementMode.scan)
                    Text(NSLocalizedString("manual.entry", comment: "")).tag(MeasurementMode.manual)
                }
                .pickerStyle(.segmented)
                .ebpHPadding()

                if mode == .scan {
                    scanContent
                } else {
                    manualContent
                }

                // ── Total ─────────────────────────────────────────────────
                if vm.totalSqFt > 0 {
                    totalSqFtBanner
                }
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }

    // MARK: - Scan Content

    private var scanContent: some View {
        VStack(spacing: EBPSpacing.md) {
            if measurements.isEmpty {
                VStack(spacing: EBPSpacing.md) {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                        .font(.system(size: 48))
                        .foregroundStyle(EBPColor.primary.opacity(0.4))
                    Text(NSLocalizedString("no.scans.yet", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("no.scans.hint", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, EBPSpacing.xl)
                .ebpHPadding()
            } else {
                VStack(spacing: 0) {
                    ForEach(measurements) { m in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation {
                                vm.selectedMeasurement = (vm.selectedMeasurement?.id == m.id) ? nil : m
                            }
                        } label: {
                            measurementRow(m, isSelected: vm.selectedMeasurement?.id == m.id)
                        }
                        .buttonStyle(.plain)

                        if m.id != measurements.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                .ebpShadowSubtle()
                .ebpHPadding()
            }
        }
    }

    private func measurementRow(_ m: Measurement, isSelected: Bool) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.sm)
                    .fill(isSelected ? EBPColor.primary : Color(.systemGray5))
                    .frame(width: 36, height: 36)
                Image(systemName: "ruler")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(m.label.isEmpty ? NSLocalizedString("untitled.scan", comment: "") : m.label)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: EBPSpacing.xs) {
                    Text(String(format: NSLocalizedString("format.sq.ft", comment: ""), Int(m.totalSqFt)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EBPColor.primary)
                    Text(String(format: NSLocalizedString("format.areas", comment: ""), m.areas.count, m.areas.count == 1 ? "" : "s"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• \(m.scanDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(EBPColor.primary)
            }
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.vertical, 10)
        .background(isSelected ? EBPColor.primary.opacity(0.04) : Color.clear)
    }

    // MARK: - Manual Content

    private var manualContent: some View {
        VStack(spacing: EBPSpacing.md) {
            ForEach($vm.manualAreas) { $area in
                HStack(spacing: EBPSpacing.sm) {
                    TextField(NSLocalizedString("area.name.input", comment: ""), text: $area.name)
                        .textInputAutocapitalization(.words)
                        .font(.subheadline)

                    HStack(spacing: 4) {
                        TextField("0", value: $area.sqFt, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        Text(NSLocalizedString("sq.ft", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if vm.manualAreas.count > 1 {
                        Button {
                            withAnimation {
                                vm.manualAreas.removeAll { $0.id == area.id }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(EBPSpacing.sm + 2)
                .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            }

            Button {
                let count = vm.manualAreas.count + 1
                vm.manualAreas.append(.init(name: NSLocalizedString("Area", comment: "") + " \(count)", sqFt: 0))
            } label: {
                Label(NSLocalizedString("add.area", comment: ""), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EBPColor.primary)
            }
        }
        .ebpHPadding()
        .onAppear {
            // Clear scan selection when switching to manual
            vm.selectedMeasurement = nil
        }
    }

    // MARK: - Total Banner

    private var totalSqFtBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("total.floor.area", comment: ""))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(String(format: NSLocalizedString("format.sq.ft", comment: ""), Int(vm.totalSqFt)))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: "square.dashed")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(EBPSpacing.lg)
        .background(EBPColor.heroGradient, in: RoundedRectangle(cornerRadius: EBPRadius.lg))
        .ebpShadowMedium()
        .ebpHPadding()
    }
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

func stepHeader(icon: String, title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: EBPSpacing.xs) {
        HStack(spacing: EBPSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.sm)
                    .fill(EBPColor.primary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(EBPColor.primary)
            }
            Text(title)
                .font(.title3.bold())
        }
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal, EBPSpacing.md)
}
