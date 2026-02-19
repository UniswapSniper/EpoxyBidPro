import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();

const inboundLeadSchema = z.object({
  params: z.object({ businessId: z.string().uuid() }),
  body: z.object({
    firstName: z.string().min(1),
    lastName: z.string().min(1),
    email: z.string().email().optional(),
    phone: z.string().optional(),
    address: z.string().optional(),
    city: z.string().optional(),
    state: z.string().optional(),
    zip: z.string().optional(),
    source: z
      .enum([
        'REFERRAL',
        'GOOGLE',
        'YELP',
        'FACEBOOK',
        'INSTAGRAM',
        'DOOR_HANGER',
        'TRADE_SHOW',
        'OTHER',
      ])
      .default('OTHER'),
    notes: z.string().optional(),
    estimatedValue: z.number().optional(),
  }),
});

router.post(
  '/inbound/:businessId',
  validate(inboundLeadSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const business = await prisma.business.findUnique({ where: { id: req.params.businessId } });
      if (!business) throw ApiError.notFound('Business');

      const lead = await prisma.lead.create({
        data: {
          ...(req.body as object),
          businessId: req.params.businessId,
          status: 'NEW',
        },
      });

      res.status(201).json(successResponse(lead));
    } catch (error) {
      next(error);
    }
  }
);

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
    source: z
      .enum([
        'REFERRAL',
        'GOOGLE',
        'YELP',
        'FACEBOOK',
        'INSTAGRAM',
        'DOOR_HANGER',
        'TRADE_SHOW',
        'OTHER',
      ])
      .default('OTHER'),
    notes: z.string().optional(),
    estimatedValue: z.number().optional(),
    followUpAt: z.string().datetime().optional(),
  }),
});

const updateLeadSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: createLeadSchema.shape.body.partial().extend({
    status: z
      .enum(['NEW', 'CONTACTED', 'SITE_VISIT_SCHEDULED', 'BID_SENT', 'WON', 'LOST'])
      .optional(),
    lostReason: z.string().optional(),
    siteVisitAt: z.string().datetime().optional(),
  }),
});

const importLeadsSchema = z.object({
  body: z.object({ csv: z.string().min(1) }),
});

router.post(
  '/import',
  validate(importLeadsSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const rows = req.body.csv.trim().split('\n');
      const headers = rows[0].split(',').map((value: string) => value.trim().toLowerCase());
      const created: string[] = [];

      for (const row of rows.slice(1)) {
        if (!row.trim()) continue;
        const values = row.split(',').map((value) => value.trim());
        const rowData = headers.reduce<Record<string, string>>((acc, header, index) => {
          acc[header] = values[index] ?? '';
          return acc;
        }, {});

        const lead = await prisma.lead.create({
          data: {
            businessId: req.user!.businessId,
            firstName: rowData.firstname || rowData.first_name,
            lastName: rowData.lastname || rowData.last_name,
            email: rowData.email || undefined,
            phone: rowData.phone || undefined,
            source: (rowData.source?.toUpperCase().replace(/\s+/g, '_') || 'OTHER') as never,
            status: (rowData.status?.toUpperCase().replace(/\s+/g, '_') || 'NEW') as never,
            notes: rowData.notes || undefined,
            lostReason: rowData.lostreason || rowData.lost_reason || undefined,
          },
        });
        created.push(lead.id);
      }

      res.status(201).json(successResponse({ importedCount: created.length, ids: created }));
    } catch (error) {
      next(error);
    }
  }
);

router.get('/lost-reasons', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const leads = await prisma.lead.findMany({
      where: {
        businessId: req.user!.businessId,
        status: 'LOST',
        NOT: { lostReason: null },
      },
      select: { lostReason: true },
    });

    const summary = leads.reduce<Record<string, number>>((acc, lead) => {
      const reason = lead.lostReason ?? 'Unknown';
      acc[reason] = (acc[reason] ?? 0) + 1;
      return acc;
    }, {});

    res.json(successResponse(summary));
  } catch (error) {
    next(error);
  }
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

    const withAge = leads.map((lead) => ({
      ...lead,
      ageInDays: Math.floor((Date.now() - lead.createdAt.getTime()) / (1000 * 60 * 60 * 24)),
    }));

    res.json(paginatedResponse(withAge, total, pageNum, limitNum));
  } catch (error) {
    next(error);
  }
});

router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const lead = await prisma.lead.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!lead) throw ApiError.notFound('Lead');
    res.json(
      successResponse({
        ...lead,
        ageInDays: Math.floor((Date.now() - lead.createdAt.getTime()) / (1000 * 60 * 60 * 24)),
      })
    );
  } catch (error) {
    next(error);
  }
});

router.post(
  '/',
  validate(createLeadSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const lead = await prisma.lead.create({
        data: { ...(req.body as object), businessId: req.user!.businessId },
      });
      res.status(201).json(successResponse(lead));
    } catch (error) {
      next(error);
    }
  }
);

router.put(
  '/:id',
  validate(updateLeadSchema),
  async (req: Request, res: Response, next: NextFunction) => {
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
  }
);

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
