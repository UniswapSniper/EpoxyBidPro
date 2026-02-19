import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

const createLeadSchema = z.object({
  body: z.object({
    firstName: z.string().min(1),
    lastName: z.string().min(1),
    email: z.string().email().optional(),
    phone: z.string().optional(),
    address: z.string().optional(),
    city: z.string().optional(),
    state: z.string().optional(),
    zip: z.string().optional(),
    source: z.enum(['REFERRAL', 'GOOGLE', 'YELP', 'FACEBOOK', 'INSTAGRAM', 'DOOR_HANGER', 'TRADE_SHOW', 'OTHER']).default('OTHER'),
    notes: z.string().optional(),
    estimatedValue: z.number().optional(),
    followUpAt: z.string().datetime().optional(),
  }),
});

const updateLeadSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: createLeadSchema.shape.body.partial().extend({
    status: z.enum(['NEW', 'CONTACTED', 'SITE_VISIT_SCHEDULED', 'BID_SENT', 'WON', 'LOST']).optional(),
    lostReason: z.string().optional(),
    siteVisitAt: z.string().datetime().optional(),
  }),
});

// ─── GET /leads ───────────────────────────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { page = '1', limit = '25', status, source } = req.query as Record<string, string>;
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    const where = {
      businessId: req.user!.businessId,
      ...(status && { status: status as never }),
      ...(source && { source: source as never }),
    };

    const [leads, total] = await Promise.all([
      prisma.lead.findMany({
        where,
        skip: (pageNum - 1) * limitNum,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.lead.count({ where }),
    ]);

    res.json(paginatedResponse(leads, total, pageNum, limitNum));
  } catch (error) {
    next(error);
  }
});

// ─── GET /leads/:id ───────────────────────────────────────────────────────────
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const lead = await prisma.lead.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!lead) throw ApiError.notFound('Lead');
    res.json(successResponse(lead));
  } catch (error) {
    next(error);
  }
});

// ─── POST /leads ──────────────────────────────────────────────────────────────
router.post('/', validate(createLeadSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const lead = await prisma.lead.create({
      data: { ...req.body as object, businessId: req.user!.businessId },
    });
    res.status(201).json(successResponse(lead));
  } catch (error) {
    next(error);
  }
});

// ─── PUT /leads/:id ───────────────────────────────────────────────────────────
router.put('/:id', validate(updateLeadSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.lead.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!existing) throw ApiError.notFound('Lead');

    const updated = await prisma.lead.update({
      where: { id: req.params.id },
      data: req.body as object,
    });
    res.json(successResponse(updated));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /leads/:id ────────────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.lead.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!existing) throw ApiError.notFound('Lead');
    await prisma.lead.delete({ where: { id: req.params.id } });
    res.json(successResponse({ deleted: true }));
  } catch (error) {
    next(error);
  }
});

export default router;
