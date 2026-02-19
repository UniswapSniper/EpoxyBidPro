import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

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
    latitude: z.number().optional(),
    longitude: z.number().optional(),
    notes: z.string().optional(),
    tags: z.array(z.string()).optional(),
    isVip: z.boolean().optional(),
    leadSource: z
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
      .optional(),
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
    tags: z.string().optional(),
    vipOnly: z.enum(['true', 'false']).optional(),
  }),
});

router.get(
  '/',
  validate(listQuerySchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { page, limit, search, type, tags, vipOnly } = req.query as {
        page: string;
        limit: string;
        search?: string;
        type?: string;
        tags?: string;
        vipOnly?: string;
      };
      const pageNum = parseInt(page, 10) || 1;
      const limitNum = parseInt(limit, 10) || 25;
      const skip = (pageNum - 1) * limitNum;
      const businessId = req.user!.businessId;

      const tagList = tags
        ?.split(',')
        .map((tag) => tag.trim())
        .filter(Boolean);

      const where = {
        businessId,
        ...(type && { type: type as never }),
        ...(vipOnly === 'true' && { isVip: true }),
        ...(tagList?.length ? { tags: { hasSome: tagList } } : {}),
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
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
            company: true,
            type: true,
            city: true,
            state: true,
            totalRevenue: true,
            isVip: true,
            tags: true,
            createdAt: true,
          },
        }),
        prisma.client.count({ where }),
      ]);

      res.json(paginatedResponse(clients, total, pageNum, limitNum));
    } catch (error) {
      next(error);
    }
  }
);

router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const client = await prisma.client.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
      include: {
        bids: { orderBy: { createdAt: 'desc' } },
        jobs: { orderBy: { scheduledDate: 'desc' } },
        invoices: { orderBy: { createdAt: 'desc' } },
        photos: { orderBy: { createdAt: 'desc' } },
        activityLogs: { orderBy: { createdAt: 'desc' }, take: 50 },
      },
    });

    if (!client) throw ApiError.notFound('Client');

    const lifetimeRevenue = client.invoices.reduce((sum, invoice) => sum + invoice.amountPaid, 0);

    res.json(
      successResponse({
        ...client,
        totalLifetimeRevenue: Number(lifetimeRevenue.toFixed(2)),
        mapPreview: {
          latitude: client.latitude,
          longitude: client.longitude,
          address: [client.address, client.city, client.state, client.zip]
            .filter(Boolean)
            .join(', '),
        },
      })
    );
  } catch (error) {
    next(error);
  }
});

router.post(
  '/:id/activity',
  validate(
    z.object({
      params: z.object({ id: z.string().uuid() }),
      body: z.object({ action: z.string().min(1), metadata: z.record(z.unknown()).optional() }),
    })
  ),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const client = await prisma.client.findFirst({
        where: { id: req.params.id, businessId: req.user!.businessId },
      });
      if (!client) throw ApiError.notFound('Client');

      const activity = await prisma.activityLog.create({
        data: {
          businessId: req.user!.businessId,
          userId: req.user!.id,
          clientId: client.id,
          action: req.body.action,
          entityType: 'Client',
          entityId: client.id,
          metadata: req.body.metadata,
        },
      });

      res.status(201).json(successResponse(activity));
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/',
  validate(createClientSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const client = await prisma.client.create({
        data: { ...(req.body as object), businessId: req.user!.businessId },
      });
      res.status(201).json(successResponse(client));
    } catch (error) {
      next(error);
    }
  }
);

router.put(
  '/:id',
  validate(updateClientSchema),
  async (req: Request, res: Response, next: NextFunction) => {
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
  }
);

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
