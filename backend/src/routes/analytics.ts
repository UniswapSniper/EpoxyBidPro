import { Router, Request, Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { successResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';

const router = Router();
router.use(authenticate);

function dateRangeFilter(range: string): { gte: Date } {
  const now = new Date();
  const days = range === '7d' ? 7 : range === '90d' ? 90 : range === '1y' ? 365 : 30;
  return { gte: new Date(now.getTime() - days * 24 * 60 * 60 * 1000) };
}

// ─── GET /analytics/dashboard ─────────────────────────────────────────────────
router.get('/dashboard', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1);

    const [
      activeJobs,
      openBids,
      overdueInvoices,
      monthRevenue,
      recentActivity,
    ] = await Promise.all([
      prisma.job.count({ where: { businessId, status: { in: ['SCHEDULED', 'IN_PROGRESS', 'PUNCH_LIST'] } } }),
      prisma.bid.count({ where: { businessId, status: { in: ['SENT', 'VIEWED'] } } }),
      prisma.invoice.count({ where: { businessId, status: 'OVERDUE' } }),
      prisma.payment.aggregate({
        where: { invoice: { businessId }, paidAt: { gte: monthStart } },
        _sum: { amount: true },
      }),
      prisma.activityLog.findMany({
        where: { businessId },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
    ]);

    res.json(successResponse({
      activeJobs,
      openBids,
      overdueInvoices,
      monthRevenue: monthRevenue._sum.amount ?? 0,
      recentActivity,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /analytics/revenue?range=30d|90d|1y ────────────────────────────────
router.get('/revenue', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const range = (req.query.range as string) ?? '30d';
    const dateFilter = dateRangeFilter(range);

    const payments = await prisma.payment.findMany({
      where: { invoice: { businessId }, paidAt: dateFilter },
      select: { amount: true, paidAt: true, method: true },
      orderBy: { paidAt: 'asc' },
    });

    const totalRevenue = payments.reduce((s, p) => s + p.amount, 0);
    const byMethod = payments.reduce<Record<string, number>>((acc, p) => {
      acc[p.method] = (acc[p.method] ?? 0) + p.amount;
      return acc;
    }, {});

    // Group by day for chart data
    const byDay = payments.reduce<Record<string, number>>((acc, p) => {
      const day = p.paidAt.toISOString().slice(0, 10);
      acc[day] = (acc[day] ?? 0) + p.amount;
      return acc;
    }, {});

    res.json(successResponse({ totalRevenue, byMethod, byDay, range }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /analytics/bids ──────────────────────────────────────────────────────
router.get('/bids', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const range = (req.query.range as string) ?? '30d';
    const dateFilter = dateRangeFilter(range);

    const [total, sent, signed, declined] = await Promise.all([
      prisma.bid.count({ where: { businessId, createdAt: dateFilter } }),
      prisma.bid.count({ where: { businessId, sentAt: dateFilter } }),
      prisma.bid.count({ where: { businessId, signedAt: dateFilter } }),
      prisma.bid.count({ where: { businessId, declinedAt: dateFilter } }),
    ]);

    const winRate = sent > 0 ? Math.round((signed / sent) * 100) : 0;

    const avgBidValue = await prisma.bid.aggregate({
      where: { businessId, createdAt: dateFilter },
      _avg: { totalPrice: true },
    });

    res.json(successResponse({
      total,
      sent,
      signed,
      declined,
      winRate,
      avgBidValue: avgBidValue._avg.totalPrice ?? 0,
      range,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /analytics/jobs/profitability ───────────────────────────────────────
router.get('/jobs/profitability', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const range = (req.query.range as string) ?? '90d';
    const dateFilter = dateRangeFilter(range);

    const jobs = await prisma.job.findMany({
      where: { businessId, status: 'COMPLETE', completedAt: dateFilter },
      select: {
        id: true,
        title: true,
        totalSqFt: true,
        completedAt: true,
        bid: { select: { totalPrice: true, materialCost: true, laborCost: true, profitMargin: true, coatingSystem: true } },
        timeEntries: { select: { hoursWorked: true } },
        invoice: { select: { totalAmount: true, amountPaid: true } },
      },
    });

    const profitability = jobs.map((j) => {
      const revenue = j.invoice?.amountPaid ?? j.bid?.totalPrice ?? 0;
      const cost = (j.bid?.materialCost ?? 0) + (j.bid?.laborCost ?? 0);
      const margin = revenue > 0 ? ((revenue - cost) / revenue) * 100 : 0;
      const actualHours = j.timeEntries.reduce((s, t) => s + (t.hoursWorked ?? 0), 0);
      return {
        jobId: j.id,
        title: j.title,
        totalSqFt: j.totalSqFt,
        revenue,
        cost,
        margin: Math.round(margin * 100) / 100,
        actualHours,
        coatingSystem: j.bid?.coatingSystem,
        completedAt: j.completedAt,
      };
    });

    res.json(successResponse({ jobs: profitability, range }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /analytics/crm/pipeline ─────────────────────────────────────────────
router.get('/crm/pipeline', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;

    const [leadsByStatus, lostReasons, topClients] = await Promise.all([
      prisma.lead.groupBy({
        by: ['status'],
        where: { businessId },
        _count: { status: true },
        _sum: { estimatedValue: true },
      }),
      prisma.lead.groupBy({
        by: ['lostReason'],
        where: { businessId, status: 'LOST', lostReason: { not: null } },
        _count: { lostReason: true },
      }),
      prisma.client.findMany({
        where: { businessId },
        orderBy: { totalRevenue: 'desc' },
        take: 10,
        select: { id: true, firstName: true, lastName: true, company: true, totalRevenue: true },
      }),
    ]);

    res.json(successResponse({ leadsByStatus, lostReasons, topClients }));
  } catch (error) {
    next(error);
  }
});

export default router;
