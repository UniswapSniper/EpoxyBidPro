import { Router, Request, Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { successResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import {
  generateWeeklySummaryPdf,
  generateProfitabilityCsv,
  generateRevenueCsv,
} from '../services/reportService';

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

// ─── GET /analytics/revenue/seasonal ─────────────────────────────────────────
router.get('/revenue/seasonal', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const years = parseInt((req.query.years as string) ?? '2', 10);
    const cutoff = new Date();
    cutoff.setFullYear(cutoff.getFullYear() - years);

    const payments = await prisma.payment.findMany({
      where: { invoice: { businessId }, paidAt: { gte: cutoff } },
      select: { amount: true, paidAt: true },
    });

    // Group by year-month
    const byMonth = payments.reduce<Record<string, number>>((acc, p) => {
      const key = `${p.paidAt.getFullYear()}-${String(p.paidAt.getMonth() + 1).padStart(2, '0')}`;
      acc[key] = (acc[key] ?? 0) + p.amount;
      return acc;
    }, {});

    // Group by month number (1-12) across all years for seasonal averages
    const byMonthNum = payments.reduce<Record<number, number[]>>((acc, p) => {
      const m = p.paidAt.getMonth() + 1;
      if (!acc[m]) acc[m] = [];
      acc[m].push(p.amount);
      return acc;
    }, {});

    const seasonalAvg = Object.entries(byMonthNum).map(([month, amounts]) => ({
      month: Number(month),
      avgRevenue: amounts.reduce((s, a) => s + a, 0) / amounts.length,
    })).sort((a, b) => a.month - b.month);

    res.json(successResponse({ byMonth, seasonalAvg }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /analytics/bids/by-type ─────────────────────────────────────────────
router.get('/bids/by-type', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const range = (req.query.range as string) ?? '90d';
    const dateFilter = dateRangeFilter(range);

    const bids = await prisma.bid.findMany({
      where: { businessId, createdAt: dateFilter },
      select: { status: true, coatingSystem: true, totalPrice: true, totalSqFt: true },
    });

    const grouped = bids.reduce<Record<string, { total: number; sent: number; signed: number; revenue: number; sqFt: number }>>((acc, b) => {
      const key = b.coatingSystem ?? 'Unknown';
      if (!acc[key]) acc[key] = { total: 0, sent: 0, signed: 0, revenue: 0, sqFt: 0 };
      acc[key].total++;
      if (['SENT', 'VIEWED', 'SIGNED', 'DECLINED'].includes(b.status)) acc[key].sent++;
      if (b.status === 'SIGNED') { acc[key].signed++; acc[key].revenue += b.totalPrice ?? 0; }
      acc[key].sqFt += b.totalSqFt ?? 0;
      return acc;
    }, {});

    const result = Object.entries(grouped).map(([system, s]) => ({
      coatingSystem: system,
      total: s.total,
      sent: s.sent,
      signed: s.signed,
      winRate: s.sent > 0 ? Math.round((s.signed / s.sent) * 100) : 0,
      revenue: s.revenue,
      avgSqFt: s.total > 0 ? Math.round(s.sqFt / s.total) : 0,
    })).sort((a, b) => b.revenue - a.revenue);

    res.json(successResponse({ breakdown: result, range }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /analytics/crm/lifetime-value ───────────────────────────────────────
router.get('/crm/lifetime-value', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;

    const clients = await prisma.client.findMany({
      where: { businessId },
      select: {
        id: true, firstName: true, lastName: true, company: true, totalRevenue: true,
        clientType: true, createdAt: true,
        invoices: { select: { amountPaid: true } },
        jobs: { select: { id: true } },
      },
    });

    const ltv = clients.map((c) => ({
      id: c.id,
      name: `${c.firstName} ${c.lastName}`.trim() || c.company,
      company: c.company,
      clientType: c.clientType,
      totalRevenue: Number(c.totalRevenue),
      jobCount: c.jobs.length,
      avgJobValue: c.jobs.length > 0 ? Number(c.totalRevenue) / c.jobs.length : 0,
      memberSinceDays: Math.floor((Date.now() - c.createdAt.getTime()) / 86_400_000),
    })).sort((a, b) => b.totalRevenue - a.totalRevenue);

    res.json(successResponse({ clients: ltv }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /analytics/reports/weekly-pdf ───────────────────────────────────────
router.get('/reports/weekly-pdf', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;

    const now = new Date();
    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - now.getDay()); // Sunday
    weekStart.setHours(0, 0, 0, 0);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekStart.getDate() + 6);
    weekEnd.setHours(23, 59, 59, 999);

    const [business, revenue, bids, jobs, leads, overdueInvoices] = await Promise.all([
      prisma.business.findUnique({ where: { id: businessId }, select: { name: true } }),
      prisma.payment.aggregate({
        where: { invoice: { businessId }, paidAt: { gte: weekStart, lte: weekEnd } },
        _sum: { amount: true },
      }),
      prisma.bid.findMany({
        where: { businessId, createdAt: { gte: weekStart, lte: weekEnd } },
        select: { status: true },
      }),
      prisma.job.findMany({
        where: { businessId },
        select: {
          title: true, status: true, completedAt: true,
          bid: { select: { totalPrice: true } },
          invoice: { select: { amountPaid: true } },
          timeEntries: { select: { hoursWorked: true } },
        },
      }),
      prisma.lead.count({ where: { businessId, createdAt: { gte: weekStart, lte: weekEnd } } }),
      prisma.invoice.count({ where: { businessId, status: 'OVERDUE' } }),
    ]);

    const topJobs = jobs
      .filter((j) => j.status === 'COMPLETE' && j.completedAt && j.completedAt >= weekStart)
      .slice(0, 5)
      .map((j) => {
        const revenue = j.invoice?.amountPaid ?? j.bid?.totalPrice ?? 0;
        const cost = 0; // simplified
        return { title: j.title, revenue: Number(revenue), margin: 0 };
      });

    const pdf = await generateWeeklySummaryPdf({
      businessName: business?.name ?? 'My Business',
      weekStart, weekEnd,
      revenue: revenue._sum.amount ?? 0,
      newBids: bids.length,
      signedBids: bids.filter((b) => b.status === 'SIGNED').length,
      activeJobs: jobs.filter((j) => ['SCHEDULED', 'IN_PROGRESS'].includes(j.status)).length,
      completedJobs: jobs.filter((j) => j.status === 'COMPLETE' && j.completedAt && j.completedAt >= weekStart).length,
      newLeads: leads,
      overdueInvoices,
      topJobs,
    });

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="weekly-summary-${now.toISOString().slice(0, 10)}.pdf"`);
    res.send(pdf);
  } catch (error) {
    next(error);
  }
});

// ─── GET /analytics/reports/export-csv?type=revenue|profitability ─────────────
router.get('/reports/export-csv', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const type = (req.query.type as string) ?? 'revenue';
    const range = (req.query.range as string) ?? '90d';
    const dateFilter = dateRangeFilter(range);

    let csv: string;
    let filename: string;

    if (type === 'profitability') {
      const jobs = await prisma.job.findMany({
        where: { businessId, status: 'COMPLETE', completedAt: dateFilter },
        select: {
          title: true, totalSqFt: true, completedAt: true,
          bid: { select: { totalPrice: true, materialCost: true, laborCost: true, coatingSystem: true } },
          invoice: { select: { amountPaid: true } },
          timeEntries: { select: { hoursWorked: true } },
        },
      });

      const rows = jobs.map((j) => {
        const revenue = Number(j.invoice?.amountPaid ?? j.bid?.totalPrice ?? 0);
        const cost = Number(j.bid?.materialCost ?? 0) + Number(j.bid?.laborCost ?? 0);
        const margin = revenue > 0 ? ((revenue - cost) / revenue) * 100 : 0;
        return {
          jobTitle: j.title,
          completedAt: j.completedAt?.toISOString().slice(0, 10) ?? '',
          totalSqFt: j.totalSqFt ?? 0,
          revenue,
          cost,
          margin: Math.round(margin * 100) / 100,
          actualHours: j.timeEntries.reduce((s, t) => s + (t.hoursWorked ?? 0), 0),
          coatingSystem: j.bid?.coatingSystem ?? '',
        };
      });

      csv = generateProfitabilityCsv(rows);
      filename = `profitability-${range}.csv`;
    } else {
      const payments = await prisma.payment.findMany({
        where: { invoice: { businessId }, paidAt: dateFilter },
        select: { amount: true, paidAt: true, method: true },
        orderBy: { paidAt: 'asc' },
      });

      const rows = payments.map((p) => ({
        date: p.paidAt.toISOString().slice(0, 10),
        amount: p.amount,
        method: p.method,
      }));

      csv = generateRevenueCsv(rows);
      filename = `revenue-${range}.csv`;
    }

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csv);
  } catch (error) {
    next(error);
  }
});

export default router;
