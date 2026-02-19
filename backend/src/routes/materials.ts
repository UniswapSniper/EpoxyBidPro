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
  productCode: z.string().optional(),
  coatingSystem: z.enum(['SINGLE_COAT_CLEAR', 'TWO_COAT_FLAKE', 'FULL_METALLIC', 'QUARTZ', 'POLYASPARTIC', 'COMMERCIAL_GRADE', 'CUSTOM']).optional(),
  unit: z.string().min(1),
  costPerUnit: z.number().positive(),
  coverageRate: z.number().positive(),
  numCoats: z.number().int().positive().default(1),
  color: z.string().optional(),
  supplier: z.string().optional(),
  supplierUrl: z.string().url().optional(),
  notes: z.string().optional(),
  isActive: z.boolean().optional(),
});

const DEFAULT_MATERIALS = [
  { name: 'SW ArmorSeal WB Epoxy', brand: 'Sherwin-Williams', productCode: 'SW-AS-WB', coatingSystem: 'TWO_COAT_FLAKE', unit: 'gal', costPerUnit: 89, coverageRate: 300, numCoats: 2 },
  { name: '100% Solids Base Epoxy', brand: 'Legacy Industrial', productCode: 'LI-100S', coatingSystem: 'COMMERCIAL_GRADE', unit: 'gal', costPerUnit: 129, coverageRate: 160, numCoats: 2 },
  { name: 'Polyaspartic UV Topcoat', brand: 'Penntek', productCode: 'PT-PC12', coatingSystem: 'POLYASPARTIC', unit: 'gal', costPerUnit: 179, coverageRate: 350, numCoats: 1 },
  { name: 'Metallic Pigment Kit', brand: 'Leggari', productCode: 'LG-MET-01', coatingSystem: 'FULL_METALLIC', unit: 'kit', costPerUnit: 145, coverageRate: 250, numCoats: 1 },
  { name: 'Quartz Broadcast Aggregate', brand: 'Prismo', productCode: 'PR-QTZ', coatingSystem: 'QUARTZ', unit: 'lb', costPerUnit: 2.5, coverageRate: 50, numCoats: 1 },
];

router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const coatingSystem = req.query.coatingSystem as string | undefined;
    const search = req.query.search as string | undefined;

    const where = {
      businessId,
      isActive: true,
      ...(coatingSystem && { coatingSystem: coatingSystem as never }),
      ...(search && {
        OR: [
          { name: { contains: search, mode: 'insensitive' as const } },
          { brand: { contains: search, mode: 'insensitive' as const } },
          { productCode: { contains: search, mode: 'insensitive' as const } },
        ],
      }),
    };

    const [total, materials] = await Promise.all([
      prisma.material.count({ where }),
      prisma.material.findMany({
        where,
        orderBy: [{ coatingSystem: 'asc' }, { name: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    res.json(paginatedResponse(materials, total, page, limit));
  } catch (error) {
    next(error);
  }
});

router.get('/coating-systems', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const coatingSystems = await prisma.material.groupBy({
      by: ['coatingSystem'],
      where: { businessId, isActive: true },
      _count: { coatingSystem: true },
      orderBy: { coatingSystem: 'asc' },
    });
    res.json(successResponse(coatingSystems));
  } catch (error) {
    next(error);
  }
});

router.get('/price-reminders', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const days = Number(req.query.days ?? 30);
    const staleDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const staleMaterials = await prisma.material.findMany({
      where: { businessId, isActive: true, updatedAt: { lt: staleDate } },
      orderBy: { updatedAt: 'asc' },
      select: { id: true, name: true, brand: true, supplier: true, updatedAt: true },
    });

    res.json(successResponse({ staleMaterials, reminderDays: days }));
  } catch (error) {
    next(error);
  }
});

router.post('/seed-defaults', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const created = await Promise.all(
      DEFAULT_MATERIALS.map((material) =>
        prisma.material.create({
          data: {
            businessId,
            ...material,
            coatingSystem: material.coatingSystem as never,
          },
        })
      )
    );

    res.status(201).json(successResponse({ created: created.length }));
  } catch (error) {
    next(error);
  }
});

router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const material = await prisma.material.findFirst({ where: { id: req.params.id, businessId } });
    if (!material) throw ApiError.notFound('Material not found');
    res.json(successResponse(material));
  } catch (error) {
    next(error);
  }
});

router.post('/', validate(MaterialSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const material = await prisma.material.create({ data: { ...req.body, businessId } });
    res.status(201).json(successResponse(material));
  } catch (error) {
    next(error);
  }
});

router.put('/:id', validate(MaterialSchema.partial()), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const existing = await prisma.material.findFirst({ where: { id: req.params.id, businessId } });
    if (!existing) throw ApiError.notFound('Material not found');

    const material = await prisma.material.update({ where: { id: req.params.id }, data: req.body });
    res.json(successResponse(material));
  } catch (error) {
    next(error);
  }
});

router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const existing = await prisma.material.findFirst({ where: { id: req.params.id, businessId } });
    if (!existing) throw ApiError.notFound('Material not found');

    await prisma.material.update({ where: { id: req.params.id }, data: { isActive: false } });
    res.json(successResponse({ deactivated: true }));
  } catch (error) {
    next(error);
  }
});

export default router;
