import Foundation

enum WorkflowActionKind {
    case leads
    case bids
    case jobs
    case collections
    case healthy
}

struct WorkflowNextAction {
    let title: String
    let subtitle: String
    let icon: String
    let kind: WorkflowActionKind
    let targetTab: WorkflowRouter.RouteTab?
}

struct WorkflowKPISnapshot {
    let readyLeads: Int
    let bidsNeedingAction: Int
    let atRiskJobs: Int
    let collectionRisks: Int
    let scansThisWeek: Int

    var totalHotspots: Int {
        readyLeads + bidsNeedingAction + atRiskJobs + collectionRisks
    }

    var headline: String {
        if totalHotspots == 0 {
            return "Workflow healthy — no urgent blockers"
        }
        return "\(totalHotspots) workflow hotspot\(totalHotspots == 1 ? "" : "s") need attention"
    }
}

enum WorkflowKPIService {
    static func snapshot(
        leads: [Lead],
        bids: [Bid],
        jobs: [Job],
        invoices: [Invoice],
        measurements: [Measurement]
    ) -> WorkflowKPISnapshot {
        let readyLeads = leads.filter {
            !["WON", "LOST"].contains($0.status) && EpoxyAIWorkflowAdvisor.followUpPriorityScore($0) >= 65
        }.count

        let bidsNeedingAction = bids.filter {
            ["DRAFT", "SENT", "VIEWED"].contains($0.status)
        }.count

        let atRiskJobs = jobs.filter {
            EpoxyAIWorkflowAdvisor.jobRiskScore($0) >= 60
        }.count

        let collectionRisks = invoices.filter {
            EpoxyAIWorkflowAdvisor.invoiceCollectionRisk($0) >= 60
        }.count

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        let scansThisWeek = measurements.filter { $0.scanDate >= weekAgo }.count

        return WorkflowKPISnapshot(
            readyLeads: readyLeads,
            bidsNeedingAction: bidsNeedingAction,
            atRiskJobs: atRiskJobs,
            collectionRisks: collectionRisks,
            scansThisWeek: scansThisWeek
        )
    }

    static func nextBestAction(from snapshot: WorkflowKPISnapshot) -> WorkflowNextAction {
        if snapshot.readyLeads > 0 {
            return WorkflowNextAction(
                title: "Follow up on hot leads",
                subtitle: "\(snapshot.readyLeads) lead\(snapshot.readyLeads == 1 ? "" : "s") are ready for contact",
                icon: "person.badge.clock",
                kind: .leads,
                targetTab: .crm
            )
        }

        if snapshot.collectionRisks > 0 {
            return WorkflowNextAction(
                title: "Collect overdue invoices",
                subtitle: "\(snapshot.collectionRisks) invoice\(snapshot.collectionRisks == 1 ? "" : "s") need payment follow-up",
                icon: "creditcard.trianglebadge.exclamationmark",
                kind: .collections,
                targetTab: .more
            )
        }

        if snapshot.atRiskJobs > 0 {
            return WorkflowNextAction(
                title: "Review at-risk jobs",
                subtitle: "\(snapshot.atRiskJobs) active job\(snapshot.atRiskJobs == 1 ? "" : "s") risk margin slip",
                icon: "exclamationmark.triangle.fill",
                kind: .jobs,
                targetTab: .jobs
            )
        }

        if snapshot.bidsNeedingAction > 0 {
            return WorkflowNextAction(
                title: "Advance open proposals",
                subtitle: "\(snapshot.bidsNeedingAction) bid\(snapshot.bidsNeedingAction == 1 ? "" : "s") waiting on send or close",
                icon: "doc.text.fill",
                kind: .bids,
                targetTab: .bids
            )
        }

        return WorkflowNextAction(
            title: "Workflow is healthy",
            subtitle: "No urgent actions — focus on new estimates and growth.",
            icon: "checkmark.seal.fill",
            kind: .healthy,
            targetTab: nil
        )
    }
}
