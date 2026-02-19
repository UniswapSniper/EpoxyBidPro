import Foundation
import SwiftData

@Model final class Area { var id: UUID = UUID(); var name: String = "" }
@Model final class LineItem { var id: UUID = UUID(); var name: String = ""; var amount: Decimal = 0 }
@Model final class Quote { var id: UUID = UUID(); var title: String = "" }
@Model final class Invoice { var id: UUID = UUID(); var number: String = "" }
@Model final class Payment { var id: UUID = UUID(); var amount: Decimal = 0 }
@Model final class Photo { var id: UUID = UUID(); var remoteURL: String = "" }
@Model final class CrewMember { var id: UUID = UUID(); var fullName: String = "" }
@Model final class Material { var id: UUID = UUID(); var name: String = "" }
@Model final class Template { var id: UUID = UUID(); var name: String = "" }
