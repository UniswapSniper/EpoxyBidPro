import SwiftUI
import SwiftData

struct PipelineClientsView: View {
    @Environment(\.modelContext) private var modelContext

    var allClients: [Client]
    var searchText: String
    
    @Binding var selectedClient: Client?
    @Binding var showAddClient: Bool
    
    private var filteredClients: [Client] {
        if searchText.isEmpty { return Array(allClients) }
        let lower = searchText.lowercased()
        return allClients.filter {
            $0.displayName.lowercased().contains(lower) ||
            $0.company.lowercased().contains(lower) ||
            $0.email.lowercased().contains(lower)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Label("Clients", systemImage: "person.2.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(allClients.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            if allClients.isEmpty {
                EBPEmptyState(
                    icon: "person.2.slash",
                    title: "No Clients",
                    subtitle: "Convert leads or add clients manually.",
                    action: ("Add Client", { showAddClient = true })
                )
            } else {
                let displayed = searchText.isEmpty ? Array(allClients.prefix(5)) : filteredClients
                if displayed.isEmpty {
                    Text("No clients found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, EBPSpacing.sm)
                } else {
                    ForEach(displayed) { client in
                        Button { selectedClient = client } label: {
                            HStack(spacing: EBPSpacing.md) {
                                ZStack {
                                    Circle().fill(EBPColor.primaryGradient).frame(width: 36, height: 36)
                                    Text(String(client.displayName.prefix(1)).uppercased())
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    if !client.company.isEmpty {
                                        Text(client.company)
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                                Text("\(client.bids.count) bids")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(EBPColor.primary)
                            }
                            .padding(EBPSpacing.sm)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        .padding(.horizontal, EBPSpacing.md)
        .padding(.bottom, EBPSpacing.xl)
    }
}
