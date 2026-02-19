import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

const MaterialSchema = z.object({
  name: z.string().min(1),
  brand: z.string().optional(),
  sku: z.string().optional(),
  category: z.string().min(1),
  unit: z.string().min(1),
  costPerUnit: z.number().positive(),
  coverageRate: z.number().positive(),     // sqFt per unit
  numCoats: z.number().int().positive().default(1),
  color: z.string().optional(),
  notes: z.string().optional(),
  isActive: z.boolean().optional(),
});

// ─── GET /materials ───────────────────────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 50;
    const category = req.query.category as string | undefined;
    const search = req.query.search as string | undefined;

    const where = {
      businessId,
      isActive: true,
      ...(category && { category }),
      ...(search && {
        OR: [
          { name: { contains: search, mode: 'insensitive' as const } },
          { brand: { contains: search, mode: 'insensitive' as const } },
          { sku: { contains: search, mode: 'insensitive' as const } },
        ],
      }),
    };

    const [total, materials] = await Promise.all([
      prisma.material.count({ where }),
      prisma.material.findMany({
        where,
        orderBy: [{ category: 'asc' }, { name: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    res.json(paginatedResponse(materials, total, page, limit));
  } catch (error) {
    next(error);
  }
});

// ─── GET /materials/categories ────────────────────────────────────────────────
router.get('/categories', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const categories = await prisma.material.groupBy({
      by: ['category'],
      where: { businessId, isActive: true },
      _count: { category: true },
      orderBy: { category: 'asc' },
    });
    res.json(successResponse(categories));
  } catch (error) {
    next(error);
  }
});

// ─── GET /materials/:id ───────────────────────────────────────────────────────
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const material = await prisma.material.findFirst({
      where: { id: req.params.id, businessId },
    });
    if (!material) throw ApiError.notFound('Material not found');
    res.json(successResponse(material));
  } catch (error) {
    next(error);
  }
});

// ─── POST /materials ──────────────────────────────────────────────────────────
router.post('/', validate(MaterialSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const material = await prisma.material.create({
      data: { ...req.body, businessId },
    });
    res.status(201).json(successResponse(material, 'Material created'));
  } catch (error) {
    next(error);
  }
});

// ─── PUT /materials/:id ───────────────────────────────────────────────────────
router.put('/:id', validate(MaterialSchema.partial()), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const existing = await prisma.material.findFirst({ where: { id: req.params.id, businessId } });
    if (!existing) throw ApiError.notFound('Material not found');

    const material = await prisma.material.update({ where: { id: req.params.id }, data: req.body });
    res.json(successResponse(material, 'Material updated'));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /materials/:id ────────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const existing = await prisma.material.findFirst({ where: { id: req.params.id, businessId } });
    if (!existing) throw ApiError.notFound('Material not found');

    // Soft delete to preserve historical bid line item references
    await prisma.material.update({ where: { id: req.params.id }, data: { isActive: false } });
    res.json(successResponse(null, 'Material deactivated'));
  } catch (error) {
    next(error);
  }
});

export default router;
