import Foundation

enum EpoxyAIWorkflowAdvisor {

    static func bidGuidance(forSqFt sqFt: Double) -> String {
        switch sqFt {
        case ..<300:
            return "Compact scope — push fast-turn polyaspartic option and premium upsell on color flakes."
        case 300..<1000:
            return "Standard residential scope — anchor with full-flake option and present a better/best ladder."
        default:
            return "Large project — phase install plan, include crew logistics buffer, and lock material lead-times early."
        }
    }

    static func leadCloseProbability(_ lead: Lead) -> Int {
        var score = 25

        switch lead.status {
        case "NEW": score += 5
        case "CONTACTED": score += 15
        case "SITE_VISIT": score += 30
        case "BID_SENT": score += 40
        case "WON": score = 100
        case "LOST": score = 0
        default: break
        }

        if let followUp = lead.followUpDate {
            let daysFromNow = Calendar.current.dateComponents([.day], from: Date(), to: followUp).day ?? 0
            if daysFromNow < 0 { score -= 12 }
            if daysFromNow <= 1 { score += 6 }
        }

        if lead.estimatedValue >= 8000 { score += 8 }
        if !lead.source.isEmpty, ["REFERRAL", "WEBSITE"].contains(lead.source.uppercased()) { score += 6 }

        return min(max(score, 0), 100)
    }

    static func followUpPriorityScore(_ lead: Lead) -> Int {
        var score = 50

        if let followUp = lead.followUpDate {
            let delta = Calendar.current.dateComponents([.day], from: followUp, to: Date()).day ?? 0
            if delta > 0 {
                score += min(delta * 6, 30)
            }
        } else {
            score += 10
        }

        score += min(Int(lead.estimatedValue / 1000), 20)

        switch lead.status {
        case "BID_SENT": score += 18
        case "SITE_VISIT": score += 14
        case "CONTACTED": score += 8
        default: break
        }

        return min(max(score, 0), 100)
    }

    static func nextBestAction(for lead: Lead) -> String {
        switch lead.status {
        case "NEW":
            return "Call within 15 minutes and confirm project goals before quoting."
        case "CONTACTED":
            return "Lock a site visit slot and capture substrate prep notes."
        case "SITE_VISIT":
            return "Build proposal from measured scope and send same day."
        case "BID_SENT":
            return "Run close call with financing/timeline options to secure signature."
        default:
            return "Review account and update next follow-up commitment."
        }
    }

    static func jobRiskScore(_ job: Job) -> Int {
        guard ["SCHEDULED", "IN_PROGRESS", "PUNCH_LIST"].contains(job.status) else { return 0 }

        var score = 10

        if job.revenue > 0 {
            let margin = ((job.revenue - job.actualCost) / job.revenue) * 100
            let marginValue = NSDecimalNumber(decimal: margin).intValue
            if marginValue < 15 { score += 55 }
            else if marginValue < 25 { score += 35 }
            else if marginValue < 30 { score += 18 }
        }

        if job.checklistItems.count > 0 {
            let completed = job.checklistItems.filter { $0.isComplete }.count
            let ratio = Double(completed) / Double(job.checklistItems.count)
            if ratio < 0.4 { score += 15 }
        }

        if let scheduled = job.scheduledDate, scheduled < Date(), job.status == "SCHEDULED" {
            score += 20
        }

        return min(max(score, 0), 100)
    }

    static func invoiceCollectionRisk(_ invoice: Invoice) -> Int {
        if invoice.status == "PAID" { return 0 }

        var score = 15
        if invoice.isOverdue {
            let days = Calendar.current.dateComponents([.day], from: invoice.dueDate, to: Date()).day ?? 0
            score += min(days * 2, 45)
        }

        let total = NSDecimalNumber(decimal: invoice.totalAmount).doubleValue
        let balance = NSDecimalNumber(decimal: invoice.balanceDue).doubleValue
        if total > 0 {
            let ratio = balance / total
            if ratio > 0.75 { score += 20 }
            else if ratio > 0.4 { score += 12 }
        }

        if invoice.stripePaymentLinkUrl.isEmpty {
            score += 8
        }

        return min(max(score, 0), 100)
    }
}
