import SwiftUI
import SwiftData

// ─── MaterialsTrackingView ────────────────────────────────────────────────────
// Per-job materials and equipment list with quantity tracking,
// cost estimation, and acquisition status toggle.

struct MaterialsTrackingView: View {

    // MARK: - Inputs

    let job: Job

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Data

    @Query private var allMaterials: [JobMaterial]
    private var materials: [JobMaterial] {
        allMaterials.filter { $0.jobId == job.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var acquiredMaterials: [JobMaterial] { materials.filter { $0.isAcquired } }
    private var pendingMaterials: [JobMaterial] { materials.filter { !$0.isAcquired } }

    private var totalEstimatedCost: Decimal {
        materials.reduce(Decimal(0)) { $0 + $1.estimatedCost * Decimal($1.quantity) }
    }

    private var acquiredCost: Decimal {
        acquiredMaterials.reduce(Decimal(0)) { $0 + $1.estimatedCost * Decimal($1.quantity) }
    }

    // MARK: - State

    @State private var showAddMaterial = false
    @State private var newName = ""
    @State private var newQuantity = "1"
    @State private var newUnit = "gal"
    @State private var newCost = ""
    @State private var newNotes = ""
    @State private var selectedPreset: MaterialPreset? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: EBPSpacing.lg) {
                    summaryBanner
                    if !pendingMaterials.isEmpty { pendingSection }
                    if !acquiredMaterials.isEmpty { acquiredSection }
                    if materials.isEmpty { emptyState }
                }
                .padding(EBPSpacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Materials & Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAddMaterial = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddMaterial) {
                addMaterialSheet
            }
        }
    }

    // MARK: - Summary Banner

    private var summaryBanner: some View {
        VStack(spacing: EBPSpacing.sm) {
            HStack(spacing: 0) {
                summaryCell(
                    value: "\(materials.count)",
                    label: "Items",
                    color: .primary
                )
                Divider().frame(height: 44)
                summaryCell(
                    value: "\(acquiredMaterials.count)/\(materials.count)",
                    label: "Acquired",
                    color: acquiredMaterials.count == materials.count && !materials.isEmpty ? .green : .orange
                )
                Divider().frame(height: 44)
                summaryCell(
                    value: (totalEstimatedCost as Decimal).formatted(.currency(code: "USD")),
                    label: "Est. Cost",
                    color: EBPColor.primary
                )
            }
            .padding(.vertical, EBPSpacing.sm)

            // Progress bar
            if !materials.isEmpty {
                VStack(spacing: 4) {
                    ProgressView(value: Double(acquiredMaterials.count), total: Double(materials.count))
                        .tint(.green)
                    Text("\(acquiredMaterials.count) of \(materials.count) items acquired")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, EBPSpacing.md)
                .padding(.bottom, EBPSpacing.sm)
            }
        }
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

    // MARK: - Pending Section

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Label("To Acquire (\(pendingMaterials.count))", systemImage: "cart")
                .font(.headline)
                .foregroundStyle(.orange)

            VStack(spacing: 0) {
                ForEach(pendingMaterials) { material in
                    materialRow(material)
                    if material.id != pendingMaterials.last?.id {
                        Divider().padding(.leading, EBPSpacing.md)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
        }
    }

    // MARK: - Acquired Section

    private var acquiredSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Label("Acquired (\(acquiredMaterials.count))", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            VStack(spacing: 0) {
                ForEach(acquiredMaterials) { material in
                    materialRow(material)
                    if material.id != acquiredMaterials.last?.id {
                        Divider().padding(.leading, EBPSpacing.md)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
        }
    }

    // MARK: - Material Row

    private func materialRow(_ material: JobMaterial) -> some View {
        HStack(spacing: EBPSpacing.md) {
            Button {
                withAnimation(EBPAnimation.snappy) {
                    material.isAcquired.toggle()
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: material.isAcquired ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(material.isAcquired ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(material.name.isEmpty ? "Unnamed Item" : material.name)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(material.isAcquired)
                    .foregroundStyle(material.isAcquired ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text("\(material.quantity.formatted()) \(material.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if material.estimatedCost > 0 {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text((material.estimatedCost * Decimal(material.quantity)).formatted(.currency(code: "USD")))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(material.isAcquired ? .green : EBPColor.primary)
                    }
                }

                if !material.notes.isEmpty {
                    Text(material.notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(EBPSpacing.md)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(material)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: EBPSpacing.md) {
            Image(systemName: "shippingbox")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No Materials Added")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to add materials from presets or enter your own.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(EBPSpacing.xxl)
    }

    // MARK: - Add Material Sheet

    private var addMaterialSheet: some View {
        NavigationStack {
            Form {
                // Preset picker
                Section("Quick Add from Preset") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: EBPSpacing.sm) {
                            ForEach(MaterialPreset.allCases) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    Text(preset.name)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(selectedPreset == preset ? EBPColor.primary : Color(.tertiarySystemBackground))
                                        .foregroundStyle(selectedPreset == preset ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Item Details") {
                    TextField("Material name", text: $newName)
                    HStack {
                        TextField("Qty", text: $newQuantity)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        Picker("Unit", selection: $newUnit) {
                            ForEach(["gal", "qt", "bag", "lb", "kit", "roll", "sheet", "ea", "box"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    HStack {
                        Text("$")
                        TextField("Est. cost per unit", text: $newCost)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Notes") {
                    TextField("Optional note", text: $newNotes)
                }

                Section {
                    Button {
                        addMaterial()
                        showAddMaterial = false
                    } label: {
                        HStack {
                            Spacer()
                            Label("Add Material", systemImage: "plus.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(newName.isEmpty)
                    .tint(EBPColor.primary)
                }
            }
            .navigationTitle("Add Material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddMaterial = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func applyPreset(_ preset: MaterialPreset) {
        selectedPreset = preset
        newName = preset.name
        newUnit = preset.unit
        newQuantity = preset.defaultQty
        newCost = preset.defaultCost
    }

    private func addMaterial() {
        let cost = Decimal(string: newCost) ?? 0
        let qty = Double(newQuantity) ?? 1
        let sortIndex = materials.count

        let material = JobMaterial(
            name: newName,
            quantity: qty,
            unit: newUnit,
            estimatedCost: cost,
            isAcquired: false,
            notes: newNotes,
            sortOrder: sortIndex,
            jobId: job.id
        )
        modelContext.insert(material)
        try? modelContext.save()

        // Reset
        newName = ""
        newQuantity = "1"
        newUnit = "gal"
        newCost = ""
        newNotes = ""
        selectedPreset = nil
    }
}

// ─── MaterialPreset ───────────────────────────────────────────────────────────

enum MaterialPreset: String, CaseIterable, Identifiable {
    case epoxyPrimer       = "epoxy_primer"
    case baseCoat          = "base_coat"
    case vinylFlake        = "vinyl_flake"
    case polyasparticTop   = "polyaspartic_top"
    case concretePatch     = "concrete_patch"
    case grinder           = "grinder_pads"
    case mixingPaddles     = "mixing_paddles"
    case rollers           = "rollers"
    case tape              = "painters_tape"
    case acetone           = "acetone"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .epoxyPrimer:     return "Epoxy Primer"
        case .baseCoat:        return "Base Coat"
        case .vinylFlake:      return "Vinyl Flake"
        case .polyasparticTop: return "Polyaspartic Topcoat"
        case .concretePatch:   return "Concrete Patch"
        case .grinder:         return "Grinder Pads"
        case .mixingPaddles:   return "Mixing Paddles"
        case .rollers:         return "Rollers (1/4\")"
        case .tape:            return "Painter's Tape"
        case .acetone:         return "Acetone"
        }
    }

    var unit: String {
        switch self {
        case .epoxyPrimer, .baseCoat, .polyasparticTop, .acetone: return "gal"
        case .vinylFlake:        return "bag"
        case .concretePatch:     return "bag"
        case .grinder:           return "ea"
        case .mixingPaddles:     return "ea"
        case .rollers:           return "ea"
        case .tape:              return "roll"
        }
    }

    var defaultQty: String {
        switch self {
        case .epoxyPrimer, .baseCoat, .polyasparticTop: return "4"
        case .vinylFlake: return "2"
        case .concretePatch: return "1"
        case .grinder, .mixingPaddles: return "2"
        case .rollers: return "6"
        case .tape: return "4"
        case .acetone: return "1"
        }
    }

    var defaultCost: String {
        switch self {
        case .epoxyPrimer:     return "65"
        case .baseCoat:        return "85"
        case .vinylFlake:      return "45"
        case .polyasparticTop: return "120"
        case .concretePatch:   return "28"
        case .grinder:         return "15"
        case .mixingPaddles:   return "8"
        case .rollers:         return "4"
        case .tape:            return "6"
        case .acetone:         return "18"
        }
    }
}
