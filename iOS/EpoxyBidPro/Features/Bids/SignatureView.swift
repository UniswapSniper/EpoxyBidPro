import SwiftUI

// ─── SignatureView ─────────────────────────────────────────────────────────────
// Native freehand drawing canvas for capturing client e-signatures.
// Produces a base64-encoded PNG that is sent to the backend.

struct SignatureView: View {

    // MARK: - Inputs

    let bid: Bid
    /// Called with the base64 PNG data url and the signer name when confirmed.
    var onSigned: (String, String, String?) -> Void
    var onCancel: () -> Void

    // MARK: - State

    @State private var lines: [SignatureLine] = []
    @State private var currentLine: SignatureLine = SignatureLine()
    @State private var signerName = ""
    @State private var signerEmail = ""
    @State private var showNameField = true
    @State private var showClearAlert = false

    private var canvasSize: CGSize { CGSize(width: UIScreen.main.bounds.width - 48, height: 200) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: EBPSpacing.lg) {

                    proposalSummaryCard

                    // ── Signer info ────────────────────────────────────────────
                    GroupBox("Authorising Party") {
                        VStack(spacing: EBPSpacing.sm) {
                            TextField("Full name (required)", text: $signerName)
                                .textContentType(.name)
                                .padding(EBPSpacing.sm)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.separator))
                                )

                            TextField("Email (optional — for receipt)", text: $signerEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(EBPSpacing.sm)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.separator))
                                )
                        }
                    }

                    // ── Signature canvas ───────────────────────────────────────
                    GroupBox {
                        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                            HStack {
                                Text("Sign below")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Button("Clear") { showClearAlert = true }
                                    .font(.subheadline)
                                    .foregroundStyle(lines.isEmpty ? .secondary : .red)
                                    .disabled(lines.isEmpty)
                            }

                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color(.separator), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(.systemBackground))
                                    )
                                    .frame(height: 200)

                                // Baseline
                                Path { path in
                                    let y = 165.0
                                    path.move(to: CGPoint(x: 24, y: y))
                                    path.addLine(to: CGPoint(x: canvasSize.width - 24, y: y))
                                }
                                .stroke(Color(.separator).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))

                                Text("× Sign here")
                                    .font(.caption)
                                    .foregroundStyle(Color(.tertiaryLabel))
                                    .offset(x: -(canvasSize.width / 2) + 60, y: 40)

                                // Drawn lines
                                Canvas { context, _ in
                                    for line in lines + [currentLine] {
                                        var path = Path()
                                        for (i, pt) in line.points.enumerated() {
                                            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                                        }
                                        context.stroke(path,
                                            with: .color(.black),
                                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                    }
                                }
                                .frame(height: 200)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let pt = value.location
                                            if currentLine.points.isEmpty {
                                                currentLine = SignatureLine()
                                            }
                                            currentLine.points.append(pt)
                                        }
                                        .onEnded { _ in
                                            lines.append(currentLine)
                                            currentLine = SignatureLine()
                                        }
                                )
                            }
                        }
                    }

                    // ── Legal notice ───────────────────────────────────────────
                    Text("By signing above, I confirm acceptance of this proposal and its terms & conditions. This constitutes a legally binding agreement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // ── Action buttons ─────────────────────────────────────────
                    VStack(spacing: EBPSpacing.sm) {
                        Button {
                            confirmSignature()
                        } label: {
                            Label("Confirm & Sign Proposal", systemImage: "checkmark.seal.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canConfirm ? EBPColor.primary : Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canConfirm)

                        Button("Cancel", role: .cancel, action: onCancel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, EBPSpacing.lg)
                }
                .padding(EBPSpacing.md)
            }
            .navigationTitle("Sign Proposal")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Clear Signature?", isPresented: $showClearAlert) {
                Button("Clear", role: .destructive) { lines = []; currentLine = SignatureLine() }
                Button("Keep", role: .cancel) {}
            }
        }
    }

    // MARK: - Proposal summary

    private var proposalSummaryCard: some View {
        HStack(spacing: EBPSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(bid.bidNumber.isEmpty ? "Draft Proposal" : "Proposal \(bid.bidNumber)")
                    .font(.headline)
                Text(bid.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(bid.totalPrice as Decimal, format: .currency(code: "USD"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(EBPColor.primary)
                Text("\(Int(bid.totalSqFt).formatted()) sq ft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(EBPColor.primary.opacity(0.2)))
    }

    // MARK: - Helpers

    private var canConfirm: Bool {
        !signerName.trimmingCharacters(in: .whitespaces).isEmpty && !lines.isEmpty
    }

    private func confirmSignature() {
        guard canConfirm else { return }

        // Render the canvas lines to a UIImage and produce a base64 PNG
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            let cgContext = ctx.cgContext
            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(2.5)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)

            for line in lines {
                guard let first = line.points.first else { continue }
                cgContext.beginPath()
                cgContext.move(to: first)
                line.points.dropFirst().forEach { cgContext.addLine(to: $0) }
                cgContext.strokePath()
            }
        }

        guard let pngData = image.pngData() else { return }
        let base64 = "data:image/png;base64," + pngData.base64EncodedString()
        let email = signerEmail.trimmingCharacters(in: .whitespaces).isEmpty ? nil : signerEmail
        onSigned(base64, signerName.trimmingCharacters(in: .whitespaces), email)
    }
}

// ─── Model ────────────────────────────────────────────────────────────────────

struct SignatureLine {
    var points: [CGPoint] = []
}
