import Foundation
import SwiftData

@Model final class Client {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model final class Lead {
    var id: UUID
    var status: String
    var source: String

    init(id: UUID = UUID(), status: String = "new", source: String = "manual") {
        self.id = id
        self.status = status
        self.source = source
    }
}

@Model final class Measurement {
    var id: UUID
    var squareFeet: Double

    init(id: UUID = UUID(), squareFeet: Double) {
        self.id = id
        self.squareFeet = squareFeet
    }
}

@Model final class Bid {
    var id: UUID
    var total: Decimal

    init(id: UUID = UUID(), total: Decimal = 0) {
        self.id = id
        self.total = total
    }
}

@Model final class Job {
    var id: UUID
    var title: String
    var scheduledDate: Date?

    init(id: UUID = UUID(), title: String, scheduledDate: Date? = nil) {
        self.id = id
        self.title = title
        self.scheduledDate = scheduledDate
    }
}
