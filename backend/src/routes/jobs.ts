import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

const createJobSchema = z.object({
  body: z.object({
    clientId: z.string().uuid(),
    bidId: z.string().uuid().optional(),
    title: z.string().min(1),
    scheduledDate: z.string().datetime().optional(),
    address: z.string().optional(),
    city: z.string().optional(),
    state: z.string().optional(),
    zip: z.string().optional(),
    notes: z.string().optional(),
    totalSqFt: z.number().nonneg().optional(),
    coatingSystem: z.enum(['SINGLE_COAT_CLEAR', 'TWO_COAT_FLAKE', 'FULL_METALLIC', 'QUARTZ', 'POLYASPARTIC', 'COMMERCIAL_GRADE', 'CUSTOM']).optional(),
    crewIds: z.array(z.string().uuid()).optional(),
  }),
});

const updateStatusSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: z.object({
    status: z.enum(['SCHEDULED', 'IN_PROGRESS', 'PUNCH_LIST', 'COMPLETE', 'INVOICED', 'PAID', 'CANCELLED']),
    notes: z.string().optional(),
  }),
});

// ─── GET /jobs ────────────────────────────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { page = '1', limit = '25', status, from, to } = req.query as Record<string, string>;
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    const where = {
      businessId: req.user!.businessId,
      ...(status && { status: status as never }),
      ...(from || to) && {
        scheduledDate: {
          ...(from && { gte: new Date(from) }),
          ...(to && { lte: new Date(to) }),
        },
      },
    };

    const [jobs, total] = await Promise.all([
      prisma.job.findMany({
        where,
        skip: (pageNum - 1) * limitNum,
        take: limitNum,
        orderBy: { scheduledDate: 'asc' },
        include: {
          client: { select: { id: true, firstName: true, lastName: true, phone: true } },
          crewAssignments: { include: { crewMember: { select: { id: true, firstName: true, lastName: true } } } },
        },
      }),
      prisma.job.count({ where }),
    ]);

    res.json(paginatedResponse(jobs, total, pageNum, limitNum));
  } catch (error) {
    next(error);
  }
});

// ─── GET /jobs/:id ────────────────────────────────────────────────────────────
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const job = await prisma.job.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
      include: {
        client: true,
        bid: { select: { id: true, bidNumber: true, totalPrice: true, lineItems: { orderBy: { order: 'asc' } } } },
        crewAssignments: { include: { crewMember: true } },
        stages: { orderBy: { order: 'asc' } },
        measurements: { include: { areas: true } },
        photos: { orderBy: { createdAt: 'desc' } },
        documents: true,
        invoice: { select: { id: true, invoiceNumber: true, status: true, totalAmount: true } },
        timeEntries: { orderBy: { clockIn: 'desc' } },
      },
    });
    if (!job) throw ApiError.notFound('Job');
    res.json(successResponse(job));
  } catch (error) {
    next(error);
  }
});

// ─── POST /jobs ───────────────────────────────────────────────────────────────
router.post('/', validate(createJobSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { crewIds, ...rest } = req.body as {
      crewIds?: string[];
      clientId: string; bidId?: string; title: string;
      scheduledDate?: string; address?: string; city?: string; state?: string; zip?: string;
      notes?: string; totalSqFt?: number; coatingSystem?: never;
    };

    const job = await prisma.job.create({
      data: {
        businessId: req.user!.businessId,
        ...rest,
        ...(crewIds && {
          crewAssignments: {
            create: crewIds.map((id) => ({ crewMemberId: id })),
          },
        }),
        // Default stages for epoxy installation workflow
        stages: {
          create: [
            { name: 'Surface Prep', order: 1 },
            { name: 'Primer / Base Coat', order: 2 },
            { name: 'Broadcast / Decorative Layer', order: 3 },
            { name: 'Topcoat', order: 4 },
            { name: 'Final Inspection & Cleanup', order: 5 },
          ],
        },
      },
      include: {
        crewAssignments: { include: { crewMember: true } },
        stages: { orderBy: { order: 'asc' } },
      },
    });

    res.status(201).json(successResponse(job));
  } catch (error) {
    next(error);
  }
});

// ─── PUT /jobs/:id/status ─────────────────────────────────────────────────────
router.put('/:id/status', validate(updateStatusSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.job.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!existing) throw ApiError.notFound('Job');

    const { status, notes } = req.body as { status: string; notes?: string };

    const data: Record<string, unknown> = { status };
    if (status === 'IN_PROGRESS' && !existing.startedAt) data.startedAt = new Date();
    if (status === 'COMPLETE' && !existing.completedAt) data.completedAt = new Date();
    if (notes) data.fieldNotes = notes;

    const updated = await prisma.job.update({ where: { id: req.params.id }, data });
    res.json(successResponse(updated));
  } catch (error) {
    next(error);
  }
});

// ─── PUT /jobs/:id ────────────────────────────────────────────────────────────
router.put('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.job.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!existing) throw ApiError.notFound('Job');

    const updated = await prisma.job.update({
      where: { id: req.params.id },
      data: req.body as never,
    });
    res.json(successResponse(updated));
  } catch (error) {
    next(error);
  }
});

// ─── POST /jobs/:id/checklist ─────────────────────────────────────────────────
router.post('/:id/checklist/:stageId', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { notes } = req.body as { notes?: string };
    const updated = await prisma.jobStage.update({
      where: { id: req.params.stageId },
      data: { isComplete: true, completedAt: new Date(), notes },
    });
    res.json(successResponse(updated));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /jobs/:id ─────────────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.job.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!existing) throw ApiError.notFound('Job');
    await prisma.job.delete({ where: { id: req.params.id } });
    res.json(successResponse({ deleted: true }));
  } catch (error) {
    next(error);
  }
});

export default router;
