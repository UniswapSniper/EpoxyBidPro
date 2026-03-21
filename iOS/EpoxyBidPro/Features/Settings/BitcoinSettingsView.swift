import SwiftUI

// ─── Bitcoin Settings View ──────────────────────────────────────────────────
// Allows the contractor to enable Bitcoin/Lightning payments via Strike.
// Strike handles BTC↔USD conversion — the contractor receives USD in their bank.

struct BitcoinSettingsView: View {

    @AppStorage("btcPaymentsEnabled") private var btcPaymentsEnabled = false
    @AppStorage("strikeApiKeyConfigured") private var strikeApiKeyConfigured = false

    @State private var strikeApiKey = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            // Enable / Disable
            Section {
                Toggle("Accept Bitcoin Payments", isOn: $btcPaymentsEnabled)
                    .tint(.orange)
            } header: {
                HStack(spacing: 8) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Bitcoin & Lightning")
                }
            } footer: {
                Text("When enabled, you can include a Bitcoin payment option on invoices. Clients pay in BTC; you receive USD deposited to your bank account via Strike.")
            }

            if btcPaymentsEnabled {
                // Strike API Key
                Section {
                    SecureField("Strike API Key", text: $strikeApiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Testing…")
                            } else {
                                Image(systemName: "checkmark.circle")
                                Text("Test Connection")
                            }
                        }
                    }
                    .disabled(strikeApiKey.isEmpty || isTesting)

                    if let testResult {
                        switch testResult {
                        case .success:
                            Label("Connected successfully", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(EBPColor.success)
                                .font(.caption)
                        case .failure(let msg):
                            Label(msg, systemImage: "xmark.circle.fill")
                                .foregroundStyle(EBPColor.danger)
                                .font(.caption)
                        }
                    }

                    if strikeApiKeyConfigured {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.orange)
                            Text("API key is configured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Strike Account")
                } footer: {
                    Text("Enter your Strike API key to connect your account. Get one at strike.me/business.")
                }

                // How it works
                Section("How It Works") {
                    infoRow(icon: "1.circle.fill", color: .orange,
                            text: "You create an invoice and enable Bitcoin payment")
                    infoRow(icon: "2.circle.fill", color: .orange,
                            text: "A QR code is generated with the exact USD amount in BTC")
                    infoRow(icon: "3.circle.fill", color: .orange,
                            text: "Your client scans and pays with any Bitcoin wallet")
                    infoRow(icon: "4.circle.fill", color: .orange,
                            text: "Strike converts BTC to USD and deposits to your bank")
                }

                // Settlement info
                Section {
                    LabeledContent("Settlement") {
                        Text("USD to your bank")
                            .font(.caption.weight(.medium))
                    }
                    LabeledContent("Networks") {
                        Text("Bitcoin + Lightning")
                            .font(.caption.weight(.medium))
                    }
                    LabeledContent("Rate Lock") {
                        Text("~15 minutes")
                            .font(.caption.weight(.medium))
                    }
                } header: {
                    Text("Details")
                }
            }
        }
        .navigationTitle("Bitcoin Payments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        // Simulate API test — in production this calls PATCH /payments/bitcoin/settings
        // and then GET /payments/bitcoin/settings to verify
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if strikeApiKey.count >= 10 {
                testResult = .success
                strikeApiKeyConfigured = true
            } else {
                testResult = .failure("Invalid API key. Check your Strike dashboard.")
                strikeApiKeyConfigured = false
            }
            isTesting = false
        }
    }
}
