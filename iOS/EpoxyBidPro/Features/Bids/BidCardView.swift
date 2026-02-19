import SwiftUI

// ─── BidCardView ──────────────────────────────────────────────────────────────
// Compact bid summary card used inside BidsView list rows.

struct BidCardView: View {

    let bid: Bid

    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {

            // ── Header row ─────────────────────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bid.bidNumber.isEmpty ? "Draft" : bid.bidNumber)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(bid.title.isEmpty ? "Untitled Bid" : bid.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer()

                BidStatusBadge(status: bid.status)
            }

            // ── Client & date row ──────────────────────────────────────────────
            if let client = bid.client {
                Label(client.displayName, systemImage: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                Label(
                    "\(Int(bid.totalSqFt).formatted()) sq ft",
                    systemImage: "square.dashed"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Text(bid.totalPrice as Decimal, format: .currency(code: "USD"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(EBPColor.primary)
            }

            // ── Footer timestamps ──────────────────────────────────────────────
            HStack(spacing: EBPSpacing.sm) {
                if let sent = bid.sentAt {
                    Label("Sent \(sent.relativeFormatted)", systemImage: "paperplane")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let signed = bid.signedAt {
                    Label("Signed \(signed.relativeFormatted)", systemImage: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

                Spacer()

                Text(bid.tier)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tierColor(bid.tier).opacity(0.15))
                    .foregroundStyle(tierColor(bid.tier))
                    .clipShape(Capsule())
            }
        }
        .padding(EBPSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "GOOD":   return .blue
        case "BETTER": return EBPColor.primary
        case "BEST":   return Color(red: 0.7, green: 0.5, blue: 0)
        default:       return .secondary
        }
    }
}

// ─── BidStatusBadge ───────────────────────────────────────────────────────────

struct BidStatusBadge: View {
    let status: String

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case "DRAFT":    return "Draft"
        case "SENT":     return "Sent"
        case "VIEWED":   return "Viewed"
        case "SIGNED":   return "✓ Signed"
        case "DECLINED": return "Declined"
        case "EXPIRED":  return "Expired"
        default:         return status.capitalized
        }
    }

    private var color: Color {
        switch status {
        case "DRAFT":    return .gray
        case "SENT":     return .blue
        case "VIEWED":   return .orange
        case "SIGNED":   return .green
        case "DECLINED": return .red
        case "EXPIRED":  return Color(.systemGray3)
        default:         return .secondary
        }
    }
}

// ─── Date helpers ─────────────────────────────────────────────────────────────

private extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
