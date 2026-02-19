/**
 * Templates Route — Phase 5
 * ─────────────────────────────────────────────────────────────────────────────
 * CRUD for bid/proposal/email/SMS templates.
 * Templates can be attached to bids to customise the proposal layout and text.
 */

import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { logger } from '../utils/logger';

const router = Router();
router.use(authenticate);

// ─── Schemas ─────────────────────────────────────────────────────────────────

const createTemplateSchema = z.object({
  body: z.object({
    name: z.string().min(1).max(120),
    type: z.enum(['bid', 'email', 'sms', 'proposal']),
    content: z.string().min(1),
    isDefault: z.boolean().optional(),
  }),
});

const updateTemplateSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: createTemplateSchema.shape.body.partial(),
});

// ─── GET /templates ───────────────────────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { type } = req.query as Record<string, string | undefined>;

    const templates = await prisma.template.findMany({
      where: {
        businessId: req.user!.businessId,
        ...(type && { type }),
      },
      orderBy: [{ isDefault: 'desc' }, { name: 'asc' }],
    });

    res.json(successResponse(templates));
  } catch (error) {
    next(error);
  }
});

// ─── GET /templates/:id ───────────────────────────────────────────────────────
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const template = await prisma.template.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!template) throw ApiError.notFound('Template');
    res.json(successResponse(template));
  } catch (error) {
    next(error);
  }
});

// ─── POST /templates ──────────────────────────────────────────────────────────
router.post(
  '/',
  validate(createTemplateSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { name, type, content, isDefault } = req.body as {
        name: string;
        type: string;
        content: string;
        isDefault?: boolean;
      };

      const businessId = req.user!.businessId;

      // If setting as default, unset other defaults of same type
      if (isDefault) {
        await prisma.template.updateMany({
          where: { businessId, type, isDefault: true },
          data: { isDefault: false },
        });
      }

      const template = await prisma.template.create({
        data: { businessId, name, type, content, isDefault: isDefault ?? false },
      });

      logger.info(`Template "${name}" (${type}) created for business ${businessId}`);
      res.status(201).json(successResponse(template));
    } catch (error) {
      next(error);
    }
  },
);

// ─── PUT /templates/:id ───────────────────────────────────────────────────────
router.put(
  '/:id',
  validate(updateTemplateSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const businessId = req.user!.businessId;
      const existing = await prisma.template.findFirst({
        where: { id: req.params.id, businessId },
      });
      if (!existing) throw ApiError.notFound('Template');

      const { isDefault, type, ...rest } = req.body as Record<string, unknown>;

      // If promoting to default, demote others
      if (isDefault) {
        const resolvedType = (type as string | undefined) ?? existing.type;
        await prisma.template.updateMany({
          where: { businessId, type: resolvedType, isDefault: true, id: { not: req.params.id } },
          data: { isDefault: false },
        });
      }

      const updated = await prisma.template.update({
        where: { id: req.params.id },
        data: { ...rest, ...(type !== undefined && { type: type as string }), ...(isDefault !== undefined && { isDefault: isDefault as boolean }) } as never,
      });

      res.json(successResponse(updated));
    } catch (error) {
      next(error);
    }
  },
);

// ─── DELETE /templates/:id ────────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.template.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!existing) throw ApiError.notFound('Template');

    // Detach from any bids using this template
    await prisma.bid.updateMany({
      where: { templateId: req.params.id },
      data: { templateId: null },
    });

    await prisma.template.delete({ where: { id: req.params.id } });
    res.json(successResponse({ deleted: true }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /templates/:id/set-default ─────────────────────────────────────────
router.post('/:id/set-default', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const template = await prisma.template.findFirst({
      where: { id: req.params.id, businessId },
    });
    if (!template) throw ApiError.notFound('Template');

    await prisma.$transaction([
      prisma.template.updateMany({
        where: { businessId, type: template.type, isDefault: true },
        data: { isDefault: false },
      }),
      prisma.template.update({
        where: { id: req.params.id },
        data: { isDefault: true },
      }),
    ]);

    res.json(successResponse({ isDefault: true }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /templates/defaults/all ─────────────────────────────────────────────
// Returns one default template per type for the business.
router.get('/defaults/all', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const defaults = await prisma.template.findMany({
      where: { businessId: req.user!.businessId, isDefault: true },
    });

    const byType = Object.fromEntries(defaults.map(t => [t.type, t]));
    res.json(successResponse(byType));
  } catch (error) {
    next(error);
  }
});

export default router;
