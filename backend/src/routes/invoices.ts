import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
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

    const business = await prisma.business.update({
      where: { id: businessId },
      data: { nextInvoiceNum: { increment: 1 } },
      select: { nextInvoiceNum: true, invoicePrefix: true, taxRate: true },
    });

    const invoiceNumber = `${business.invoicePrefix}-${business.nextInvoiceNum - 1}`;
    const subtotal = lineItems.reduce((s, li) => s + li.quantity * li.unitPrice, 0);
    const taxRate = business.taxRate;
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
            ...li,
            totalPrice: li.quantity * li.unitPrice,
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
