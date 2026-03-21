import SwiftUI
import CoreImage.CIFilterBuiltins

// ─── Bitcoin Payment View ───────────────────────────────────────────────────
// Displays a QR code for Bitcoin/Lightning payment on an invoice.
// Generates a Strike invoice, shows the QR, and polls for payment status.

struct BitcoinPaymentView: View {

    @Bindable var invoice: Invoice

    @State private var isGenerating = false
    @State private var paymentUri = ""
    @State private var amountBtcSats: Int = 0
    @State private var exchangeRate: Double = 0
    @State private var expiresAt: Date?
    @State private var strikeInvoiceId = ""
    @State private var paymentState: PaymentState = .idle
    @State private var errorMessage = ""
    @State private var copiedUri = false
    @State private var pollTimer: Timer?

    enum PaymentState {
        case idle
        case pending
        case paid
        case expired
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            // Header
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                Text("Bitcoin Payment")
                    .font(.headline)
            }

            switch paymentState {
            case .idle:
                idleView
            case .pending:
                pendingView
            case .paid:
                paidView
            case .expired:
                expiredView
            }

            if !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(EBPColor.danger)
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .onDisappear {
            stopPolling()
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: EBPSpacing.sm) {
            Text("Generate a Bitcoin/Lightning invoice for your client to scan and pay.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                generateBitcoinInvoice()
            } label: {
                HStack {
                    Spacer()
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Generating…")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "bitcoinsign.circle.fill")
                        Text("Generate Bitcoin Invoice")
                            .font(.headline)
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(.orange, in: RoundedRectangle(cornerRadius: EBPRadius.md))
            }
            .disabled(isGenerating)
        }
    }

    // MARK: - Pending State (QR Code + Timer)

    private var pendingView: some View {
        VStack(spacing: EBPSpacing.md) {
            // QR Code
            if let qrImage = generateQRCode(from: paymentUri) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
                    .padding(EBPSpacing.sm)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            }

            // Amount info
            VStack(spacing: 4) {
                Text("\(invoice.balanceDue, format: .currency(code: "USD"))")
                    .font(.title2.weight(.black))
                Text("\(formattedSats) sats")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                if exchangeRate > 0 {
                    Text("Rate: \(exchangeRate, specifier: "%.2f") USD/BTC")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Countdown timer
            if let expiresAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(expiresAt, style: .timer)
                        .font(.caption.weight(.semibold).monospacedDigit())
                    Text("remaining")
                        .font(.caption)
                }
                .foregroundStyle(timeRemainingColor)
            }

            // Waiting indicator
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for payment…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Actions
            HStack(spacing: EBPSpacing.sm) {
                Button {
                    UIPasteboard.general.string = paymentUri
                    withAnimation { copiedUri = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedUri = false }
                    }
                } label: {
                    Label(copiedUri ? "Copied!" : "Copy", systemImage: copiedUri ? "checkmark" : "doc.on.clipboard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(copiedUri ? EBPColor.success : .orange, in: Capsule())
                }

                ShareLink(item: paymentUri) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.10), in: Capsule())
                }
            }
        }
    }

    // MARK: - Paid State

    private var paidView: some View {
        VStack(spacing: EBPSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(EBPColor.success)

            Text("Payment Received!")
                .font(.headline.weight(.bold))
                .foregroundStyle(EBPColor.success)

            Text("\(invoice.balanceDue, format: .currency(code: "USD")) paid via Bitcoin")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(EBPSpacing.md)
    }

    // MARK: - Expired State

    private var expiredView: some View {
        VStack(spacing: EBPSpacing.sm) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title)
                .foregroundStyle(EBPColor.warning)

            Text("Invoice expired. The exchange rate has changed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                paymentState = .idle
                errorMessage = ""
                generateBitcoinInvoice()
            } label: {
                Label("Generate New Invoice", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.orange, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 10.0
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - API Calls

    private func generateBitcoinInvoice() {
        isGenerating = true
        errorMessage = ""

        // In production, this calls POST /payments/bitcoin/create-invoice
        // For now, simulate the response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let mockSats = Int(NSDecimalNumber(decimal: invoice.balanceDue).doubleValue * 1450) // ~$69k/BTC
            let mockRate = 69000.0

            strikeInvoiceId = "strike_inv_\(UUID().uuidString.prefix(8))"
            paymentUri = "bitcoin:bc1qmock\(UUID().uuidString.prefix(12))?amount=\(Double(mockSats) / 1e8)&lightning=lnbc\(UUID().uuidString.prefix(20))"
            amountBtcSats = mockSats
            exchangeRate = mockRate
            expiresAt = Date().addingTimeInterval(15 * 60) // 15 minutes

            invoice.strikeInvoiceId = strikeInvoiceId
            invoice.btcPaymentUri = paymentUri

            paymentState = .pending
            isGenerating = false

            startPolling()
        }
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            checkPaymentStatus()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkPaymentStatus() {
        // Check if invoice has expired
        if let expiresAt, Date() > expiresAt {
            stopPolling()
            paymentState = .expired
            return
        }

        // In production, this calls GET /payments/bitcoin/check-status/:strikeInvoiceId
        // The status would update paymentState to .paid when confirmed
    }

    // MARK: - Helpers

    private var formattedSats: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: amountBtcSats)) ?? "\(amountBtcSats)"
    }

    private var timeRemainingColor: Color {
        guard let expiresAt else { return .secondary }
        let remaining = expiresAt.timeIntervalSinceNow
        if remaining < 120 { return EBPColor.danger }
        if remaining < 300 { return EBPColor.warning }
        return .secondary
    }
}
