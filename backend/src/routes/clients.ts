import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

// ─── Schemas ─────────────────────────────────────────────────────────────────

const createClientSchema = z.object({
  body: z.object({
    firstName: z.string().min(1),
    lastName: z.string().min(1),
    email: z.string().email().optional(),
    phone: z.string().optional(),
    company: z.string().optional(),
    type: z.enum(['RESIDENTIAL', 'COMMERCIAL', 'MULTI_FAMILY', 'INDUSTRIAL']).optional(),
    address: z.string().optional(),
    city: z.string().optional(),
    state: z.string().optional(),
    zip: z.string().optional(),
    notes: z.string().optional(),
    tags: z.array(z.string()).optional(),
    leadSource: z.enum(['REFERRAL', 'GOOGLE', 'YELP', 'FACEBOOK', 'INSTAGRAM', 'DOOR_HANGER', 'TRADE_SHOW', 'OTHER']).optional(),
  }),
});

const updateClientSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: createClientSchema.shape.body.partial(),
});

const listQuerySchema = z.object({
  query: z.object({
    page: z.coerce.number().min(1).default(1),
    limit: z.coerce.number().min(1).max(100).default(25),
    search: z.string().optional(),
    type: z.enum(['RESIDENTIAL', 'COMMERCIAL', 'MULTI_FAMILY', 'INDUSTRIAL']).optional(),
  }),
});

// ─── GET /clients ─────────────────────────────────────────────────────────────
router.get('/', validate(listQuerySchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { page, limit, search, type } = req.query as {
      page: string; limit: string; search?: string; type?: string;
    };
    const pageNum = parseInt(page, 10) || 1;
    const limitNum = parseInt(limit, 10) || 25;
    const skip = (pageNum - 1) * limitNum;
    const businessId = req.user!.businessId;

    const where = {
      businessId,
      ...(type && { type: type as never }),
      ...(search && {
        OR: [
          { firstName: { contains: search, mode: 'insensitive' as const } },
          { lastName: { contains: search, mode: 'insensitive' as const } },
          { email: { contains: search, mode: 'insensitive' as const } },
          { company: { contains: search, mode: 'insensitive' as const } },
        ],
      }),
    };

    const [clients, total] = await Promise.all([
      prisma.client.findMany({
        where,
        skip,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true, firstName: true, lastName: true, email: true, phone: true,
          company: true, type: true, city: true, state: true, totalRevenue: true,
          isVip: true, tags: true, createdAt: true,
        },
      }),
      prisma.client.count({ where }),
    ]);

    res.json(paginatedResponse(clients, total, pageNum, limitNum));
  } catch (error) {
    next(error);
  }
});

// ─── GET /clients/:id ─────────────────────────────────────────────────────────
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const client = await prisma.client.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
      include: {
        bids: { select: { id: true, bidNumber: true, status: true, totalPrice: true, createdAt: true }, orderBy: { createdAt: 'desc' }, take: 10 },
        jobs: { select: { id: true, title: true, status: true, scheduledDate: true }, orderBy: { scheduledDate: 'desc' }, take: 10 },
        invoices: { select: { id: true, invoiceNumber: true, status: true, totalAmount: true, amountDue: true }, orderBy: { createdAt: 'desc' }, take: 10 },
        activityLogs: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });

    if (!client) throw ApiError.notFound('Client');
    res.json(successResponse(client));
  } catch (error) {
    next(error);
  }
});

// ─── POST /clients ────────────────────────────────────────────────────────────
router.post('/', validate(createClientSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const client = await prisma.client.create({
      data: { ...req.body as object, businessId: req.user!.businessId },
    });
    res.status(201).json(successResponse(client));
  } catch (error) {
    next(error);
  }
});

// ─── PUT /clients/:id ────────────────────────────────────────────────────────
router.put('/:id', validate(updateClientSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.client.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!existing) throw ApiError.notFound('Client');

    const updated = await prisma.client.update({
      where: { id: req.params.id },
      data: req.body as object,
    });
    res.json(successResponse(updated));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /clients/:id ──────────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.client.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!existing) throw ApiError.notFound('Client');

    await prisma.client.delete({ where: { id: req.params.id } });
    res.json(successResponse({ deleted: true }));
  } catch (error) {
    next(error);
  }
});

export default router;
