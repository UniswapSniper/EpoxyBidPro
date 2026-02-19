import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

const createInvoiceSchema = z.object({
  body: z.object({
    clientId: z.string().uuid(),
    jobId: z.string().uuid().optional(),
    dueDate: z.string().datetime().optional(),
    notes: z.string().optional(),
    discountAmount: z.number().nonneg().optional(),
    lineItems: z.array(z.object({
      description: z.string().min(1),
      quantity: z.number().positive(),
      unit: z.string().optional(),
      unitPrice: z.number().nonneg(),
      bidLineItemId: z.string().uuid().optional(),
      order: z.number().int().optional(),
    })).min(1),
  }),
});

const createFromJobSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: z.object({
    invoiceType: z.enum(['DEPOSIT', 'PROGRESS', 'FINAL']).default('FINAL'),
    percentage: z.number().positive().max(100).optional(),
    dueDate: z.string().datetime().optional(),
    notes: z.string().optional(),
    applyTax: z.boolean().default(true),
    discountAmount: z.number().nonnegative().optional(),
    adjustments: z.array(z.object({
      description: z.string().min(1),
      amount: z.number(),
    })).optional(),
  }),
});

const reminderSchema = z.object({
  body: z.object({
    message: z.string().min(3).optional(),
  }),
});

const invoiceExportSchema = z.object({
  query: z.object({
    format: z.enum(['csv']).default('csv'),
  }),
});

const toCsv = (rows: Record<string, string | number | null>[]) => {
  if (rows.length === 0) return '';
  const headers = Object.keys(rows[0]);
  const esc = (v: string | number | null) => {
    if (v === null || v === undefined) return '';
    const str = String(v);
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  };

  return [
    headers.join(','),
    ...rows.map((row) => headers.map((h) => esc(row[h])).join(',')),
  ].join('\n');
};

const createInvoiceNumber = async (businessId: string) => {
  const business = await prisma.business.update({
    where: { id: businessId },
    data: { nextInvoiceNum: { increment: 1 } },
    select: { nextInvoiceNum: true, invoicePrefix: true, taxRate: true },
  });

  return {
    invoiceNumber: `${business.invoicePrefix}-${business.nextInvoiceNum - 1}`,
    taxRate: business.taxRate,
  };
};

// ─── GET /invoices ────────────────────────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { page = '1', limit = '25', status } = req.query as Record<string, string>;
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    const where = {
      businessId: req.user!.businessId,
      ...(status && { status: status as never }),
    };

    const [invoices, total] = await Promise.all([
      prisma.invoice.findMany({
        where,
        skip: (pageNum - 1) * limitNum,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
        include: {
          client: { select: { id: true, firstName: true, lastName: true } },
        },
      }),
      prisma.invoice.count({ where }),
    ]);

    res.json(paginatedResponse(invoices, total, pageNum, limitNum));
  } catch (error) {
    next(error);
  }
});

router.get('/reports/aging', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const now = new Date();
    const invoices = await prisma.invoice.findMany({
      where: {
        businessId: req.user!.businessId,
        status: { in: ['SENT', 'PARTIALLY_PAID', 'OVERDUE'] },
        amountDue: { gt: 0 },
      },
      select: { id: true, invoiceNumber: true, amountDue: true, dueDate: true, client: { select: { firstName: true, lastName: true } } },
    });

    const buckets = {
      current: 0,
      overdue30: 0,
      overdue60: 0,
      overdue90plus: 0,
    };

    for (const inv of invoices) {
      if (!inv.dueDate) {
        buckets.current += inv.amountDue;
        continue;
      }
      const daysOverdue = Math.floor((now.getTime() - inv.dueDate.getTime()) / (1000 * 60 * 60 * 24));
      if (daysOverdue <= 0) buckets.current += inv.amountDue;
      else if (daysOverdue <= 30) buckets.overdue30 += inv.amountDue;
      else if (daysOverdue <= 60) buckets.overdue60 += inv.amountDue;
      else buckets.overdue90plus += inv.amountDue;
    }

    res.json(successResponse({ buckets, invoices }));
  } catch (error) {
    next(error);
  }
});

router.get('/export', validate(invoiceExportSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const invoices = await prisma.invoice.findMany({
      where: { businessId: req.user!.businessId },
      include: { client: { select: { firstName: true, lastName: true } } },
      orderBy: { createdAt: 'desc' },
    });

    const csv = toCsv(invoices.map((inv: { invoiceNumber: string; status: string; subtotal: number; taxAmount: number; totalAmount: number; amountPaid: number; amountDue: number; dueDate: Date | null; createdAt: Date; client: { firstName: string; lastName: string } }) => ({
      invoiceNumber: inv.invoiceNumber,
      status: inv.status,
      client: `${inv.client.firstName} ${inv.client.lastName}`,
      subtotal: inv.subtotal,
      taxAmount: inv.taxAmount,
      totalAmount: inv.totalAmount,
      amountPaid: inv.amountPaid,
      amountDue: inv.amountDue,
      dueDate: inv.dueDate?.toISOString() ?? null,
      createdAt: inv.createdAt.toISOString(),
    })));

    res.header('Content-Type', 'text/csv');
    res.attachment('invoices-export.csv');
    res.send(csv);
  } catch (error) {
    next(error);
  }
});

// ─── GET /invoices/:id ────────────────────────────────────────────────────────
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const invoice = await prisma.invoice.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
      include: {
        client: true,
        lineItems: { orderBy: { order: 'asc' } },
        payments: { orderBy: { paidAt: 'desc' } },
        job: { select: { id: true, title: true, completedAt: true } },
      },
    });
    if (!invoice) throw ApiError.notFound('Invoice');
    res.json(successResponse(invoice));
  } catch (error) {
    next(error);
  }
});

// ─── POST /invoices ───────────────────────────────────────────────────────────
router.post('/', validate(createInvoiceSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const { lineItems, clientId, jobId, dueDate, notes, discountAmount } = req.body as {
      lineItems: Array<{ description: string; quantity: number; unit?: string; unitPrice: number; bidLineItemId?: string; order?: number }>;
      clientId: string; jobId?: string; dueDate?: string; notes?: string; discountAmount?: number;
    };

    const { invoiceNumber, taxRate } = await createInvoiceNumber(businessId);
    const subtotal = lineItems.reduce((s, li) => s + li.quantity * li.unitPrice, 0);
    const taxAmount = subtotal * taxRate;
    const discount = discountAmount ?? 0;
    const totalAmount = subtotal + taxAmount - discount;

    const invoice = await prisma.invoice.create({
      data: {
        businessId,
        clientId,
        jobId,
        invoiceNumber,
        subtotal,
        taxRate,
        taxAmount,
        discountAmount: discount,
        totalAmount,
        amountDue: totalAmount,
        dueDate: dueDate ? new Date(dueDate) : undefined,
        notes,
        lineItems: {
          create: lineItems.map((li, i) => ({
            description: li.description,
            quantity: li.quantity,
            unit: li.unit,
            unitPrice: li.unitPrice,
            totalPrice: li.quantity * li.unitPrice,
            lineItemId: li.bidLineItemId,
            order: li.order ?? i,
          })),
        },
      },
      include: { lineItems: { orderBy: { order: 'asc' } } },
    });

    res.status(201).json(successResponse(invoice));
  } catch (error) {
    next(error);
  }
});

router.post('/from-job/:id', validate(createFromJobSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { invoiceType, percentage, dueDate, notes, applyTax, discountAmount = 0, adjustments = [] } = req.body as {
      invoiceType: 'DEPOSIT' | 'PROGRESS' | 'FINAL';
      percentage?: number;
      dueDate?: string;
      notes?: string;
      applyTax: boolean;
      discountAmount?: number;
      adjustments?: Array<{ description: string; amount: number }>;
    };

    const job = await prisma.job.findFirst({
      where: { id, businessId: req.user!.businessId },
      include: {
        bid: { include: { lineItems: { orderBy: { order: 'asc' } } } },
        invoice: true,
      },
    });
    if (!job) throw ApiError.notFound('Job');
    if (!job.completedAt && invoiceType === 'FINAL') throw ApiError.badRequest('Job must be completed before creating a final invoice');

    const { invoiceNumber, taxRate: businessTaxRate } = await createInvoiceNumber(req.user!.businessId);
    const bidTotal = job.bid?.totalPrice ?? 0;
    const pct = percentage ? percentage / 100 : invoiceType === 'DEPOSIT' ? 0.3 : invoiceType === 'PROGRESS' ? 0.5 : 1;
    const baseSubtotal = Math.max(bidTotal * pct, 0);

    const lineItems = [
      {
        description: `${invoiceType} billing for ${job.title}`,
        quantity: 1,
        unit: 'job',
        unitPrice: baseSubtotal,
        totalPrice: baseSubtotal,
        order: 0,
      },
      ...adjustments.map((adj, i) => ({
        description: adj.description,
        quantity: 1,
        unit: 'adj',
        unitPrice: adj.amount,
        totalPrice: adj.amount,
        order: i + 1,
      })),
    ];

    const subtotal = lineItems.reduce((sum, li) => sum + li.totalPrice, 0);
    const taxRate = applyTax ? businessTaxRate : 0;
    const taxAmount = subtotal * taxRate;
    const totalAmount = Math.max(subtotal + taxAmount - discountAmount, 0);

    const created = await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      const invoice = await tx.invoice.create({
        data: {
          businessId: req.user!.businessId,
          clientId: job.clientId,
          jobId: invoiceType === 'FINAL' && !job.invoice ? job.id : undefined,
          invoiceNumber,
          subtotal,
          taxRate,
          taxAmount,
          discountAmount,
          totalAmount,
          amountDue: totalAmount,
          dueDate: dueDate ? new Date(dueDate) : undefined,
          notes: [notes, `Generated from job ${job.title}`].filter(Boolean).join(' | '),
          lineItems: { create: lineItems },
        },
        include: { lineItems: { orderBy: { order: 'asc' } } },
      });

      await tx.job.update({
        where: { id: job.id },
        data: { status: invoiceType === 'FINAL' ? 'INVOICED' : job.status },
      });

      return invoice;
    });

    res.status(201).json(successResponse(created));
  } catch (error) {
    next(error);
  }
});

// ─── POST /invoices/:id/send ──────────────────────────────────────────────────
router.post('/:id/send', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const invoice = await prisma.invoice.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!invoice) throw ApiError.notFound('Invoice');

    // TODO: generate PDF, send via SendGrid
    const updated = await prisma.invoice.update({
      where: { id: req.params.id },
      data: { status: 'SENT', sentAt: new Date() },
    });

    res.json(successResponse({ sent: true, invoiceNumber: updated.invoiceNumber, sentAt: updated.sentAt }));
  } catch (error) {
    next(error);
  }
});

router.post('/:id/remind', validate(reminderSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const invoice = await prisma.invoice.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!invoice) throw ApiError.notFound('Invoice');

    if (invoice.amountDue <= 0) throw ApiError.badRequest('Invoice already paid');
    const isOverdue = !!invoice.dueDate && invoice.dueDate.getTime() < Date.now();

    const updated = await prisma.invoice.update({
      where: { id: invoice.id },
      data: { status: isOverdue ? 'OVERDUE' : invoice.status },
    });

    res.json(successResponse({
      reminded: true,
      channel: ['email', 'push'],
      invoiceNumber: invoice.invoiceNumber,
      message: req.body.message ?? `Reminder: invoice ${invoice.invoiceNumber} has a balance of $${invoice.amountDue.toFixed(2)}.`,
      status: updated.status,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /invoices/:id ─────────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const invoice = await prisma.invoice.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!invoice) throw ApiError.notFound('Invoice');
    if (invoice.status === 'PAID') throw ApiError.badRequest('Cannot delete a paid invoice');

    await prisma.invoice.update({ where: { id: req.params.id }, data: { status: 'VOIDED' } });
    res.json(successResponse({ voided: true }));
  } catch (error) {
    next(error);
  }
});

export default router;
