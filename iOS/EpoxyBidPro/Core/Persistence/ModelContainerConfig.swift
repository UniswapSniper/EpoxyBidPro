import Foundation
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════════
// ModelContainerConfig.swift
// Factory for SwiftData ModelContainer — single source of truth for all models.
// ═══════════════════════════════════════════════════════════════════════════════

enum ModelContainerConfig {

    /// All SwiftData model types registered in the app.
    static let allModelTypes: [any PersistentModel.Type] = [
        Client.self,
        Lead.self,
        Measurement.self,
        Area.self,
        Bid.self,
        BidLineItem.self,
        BidSignature.self,
        Job.self,
        JobChecklistItem.self,
        Invoice.self,
        InvoiceLineItem.self,
        Payment.self,
        Photo.self,
        CrewMember.self,
        Material.self,
        Template.self,
    ]

    /// Creates the production ModelContainer.
    static func createContainer() throws -> ModelContainer {
        let schema = Schema(allModelTypes)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Creates an in-memory container for previews and tests.
    static func createPreviewContainer() throws -> ModelContainer {
        let schema = Schema(allModelTypes)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
