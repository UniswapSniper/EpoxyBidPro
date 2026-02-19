import SwiftUI

// ─── BidCardView ──────────────────────────────────────────────────────────────
// Compact bid summary card used inside BidsView list rows.

struct BidCardView: View {

    let bid: Bid

    var body: some View {
        HStack(spacing: 0) {

            // ── Status stripe ──────────────────────────────────────────────
            RoundedRectangle(cornerRadius: EBPRadius.xs)
                .fill(bid.statusColor)
                .frame(width: 4)
                .padding(.vertical, EBPSpacing.xs)

            // ── Card content ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: EBPSpacing.sm) {

                // Header row
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

                // Client
                if let client = bid.client {
                    Label(client.displayName, systemImage: "person")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Metrics row
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

                // Footer
                HStack(spacing: EBPSpacing.sm) {
                    if let sent = bid.sentAt {
                        Label("Sent \(sent.relativeFormatted)", systemImage: "paperplane")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let signed = bid.signedAt {
                        Label("Signed \(signed.relativeFormatted)", systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(EBPColor.success)
                    }

                    Spacer()

                    EBPPillTag(text: bid.tier.capitalized, color: tierColor(bid.tier))
                }
            }
            .padding(EBPSpacing.md)
        }
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "GOOD":   return .blue
        case "BETTER": return EBPColor.primary
        case "BEST":   return EBPColor.gold
        default:       return .secondary
        }
    }
}

// ─── BidStatusBadge ───────────────────────────────────────────────────────────

struct BidStatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 4) {
            if status == "SIGNED" {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(label)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color, in: Capsule())
    }

    private var label: String {
        switch status {
        case "DRAFT":    return "Draft"
        case "SENT":     return "Sent"
        case "VIEWED":   return "Viewed"
        case "SIGNED":   return "Signed"
        case "DECLINED": return "Declined"
        case "EXPIRED":  return "Expired"
        default:         return status.capitalized
        }
    }

    private var color: Color {
        switch status {
        case "DRAFT":    return Color(.systemGray3)
        case "SENT":     return .blue
        case "VIEWED":   return EBPColor.warning
        case "SIGNED":   return EBPColor.success
        case "DECLINED": return EBPColor.danger
        case "EXPIRED":  return Color(.systemGray4)
        default:         return .secondary
        }
    }
}

// ─── Bid model status helpers ─────────────────────────────────────────────────

extension Bid {
    var statusColor: Color {
        switch status {
        case "DRAFT":    return Color(.systemGray3)
        case "SENT":     return .blue
        case "VIEWED":   return EBPColor.warning
        case "SIGNED":   return EBPColor.success
        case "DECLINED": return EBPColor.danger
        case "EXPIRED":  return Color(.systemGray4)
        default:         return EBPColor.primary
        }
    }
}

// ─── Date helpers ─────────────────────────────────────────────────────────────

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
