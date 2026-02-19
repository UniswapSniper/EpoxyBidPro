import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

// ─── Schemas ─────────────────────────────────────────────────────────────────

const createMeasurementSchema = z.object({
  body: z.object({
    name: z.string().optional(),
    totalSqFt: z.number().positive(),
    isLidar: z.boolean().optional(),
    scanDataJson: z.record(z.unknown()).optional(),
    floorPlanUrl: z.string().url().optional(),
    notes: z.string().optional(),
    clientId: z.string().uuid().optional(),
    jobId: z.string().uuid().optional(),
    areas: z.array(z.object({
      label: z.string().min(1),
      sqFt: z.number().positive(),
      polygonJson: z.record(z.unknown()).optional(),
      notes: z.string().optional(),
      order: z.number().int().optional(),
    })).optional(),
  }),
});

// ─── GET /measurements?jobId=&clientId= ──────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { jobId, clientId, page = '1', limit = '25' } = req.query as Record<string, string>;
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    const where = {
      ...(jobId && { jobId }),
      ...(clientId && { clientId }),
    };

    const [measurements, total] = await Promise.all([
      prisma.measurement.findMany({
        where,
        skip: (pageNum - 1) * limitNum,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
        include: { areas: { orderBy: { order: 'asc' } } },
      }),
      prisma.measurement.count({ where }),
    ]);

    res.json(paginatedResponse(measurements, total, pageNum, limitNum));
  } catch (error) {
    next(error);
  }
});

// ─── GET /measurements/:id ────────────────────────────────────────────────────
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const measurement = await prisma.measurement.findUnique({
      where: { id: req.params.id },
      include: { areas: { orderBy: { order: 'asc' } } },
    });
    if (!measurement) throw ApiError.notFound('Measurement');
    res.json(successResponse(measurement));
  } catch (error) {
    next(error);
  }
});

// ─── POST /measurements ───────────────────────────────────────────────────────
router.post('/', validate(createMeasurementSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { areas, ...rest } = req.body as {
      areas?: Array<{ label: string; sqFt: number; polygonJson?: Record<string, unknown>; notes?: string; order?: number }>;
      name?: string;
      totalSqFt: number;
      isLidar?: boolean;
      scanDataJson?: Record<string, unknown>;
      floorPlanUrl?: string;
      notes?: string;
      clientId?: string;
      jobId?: string;
    };

    const measurement = await prisma.measurement.create({
      data: {
        ...rest,
        ...(areas && {
          areas: {
            create: areas.map((a, i) => ({ ...a, order: a.order ?? i })),
          },
        }),
      },
      include: { areas: { orderBy: { order: 'asc' } } },
    });

    res.status(201).json(successResponse(measurement));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /measurements/:id ─────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.measurement.findUnique({ where: { id: req.params.id } });
    if (!existing) throw ApiError.notFound('Measurement');
    await prisma.measurement.delete({ where: { id: req.params.id } });
    res.json(successResponse({ deleted: true }));
  } catch (error) {
    next(error);
  }
});

export default router;
