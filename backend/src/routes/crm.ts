import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

const pipelineQuerySchema = z.object({
  query: z.object({
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
      .optional(),
    minValue: z.coerce.number().optional(),
    maxValue: z.coerce.number().optional(),
    createdAfter: z.string().datetime().optional(),
    createdBefore: z.string().datetime().optional(),
  }),
});

router.get(
  '/pipeline',
  validate(pipelineQuerySchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { source, minValue, maxValue, createdAfter, createdBefore } = req.query as Record<
        string,
        string | undefined
      >;
      const where = {
        businessId: req.user!.businessId,
        ...(source && { source: source as never }),
        ...(minValue && { estimatedValue: { gte: Number(minValue) } }),
        ...(maxValue && {
          estimatedValue: { ...(minValue ? { gte: Number(minValue) } : {}), lte: Number(maxValue) },
        }),
        ...(createdAfter || createdBefore
          ? {
              createdAt: {
                ...(createdAfter ? { gte: new Date(createdAfter) } : {}),
                ...(createdBefore ? { lte: new Date(createdBefore) } : {}),
              },
            }
          : {}),
      };

      const leads = await prisma.lead.findMany({ where, orderBy: { createdAt: 'desc' } });
      const stages = [
        'NEW',
        'CONTACTED',
        'SITE_VISIT_SCHEDULED',
        'BID_SENT',
        'WON',
        'LOST',
      ] as const;

      const board = stages.map((stage) => {
        const stageLeads = leads.filter((lead) => lead.status === stage);
        const stageRevenue = stageLeads.reduce((acc, lead) => acc + (lead.estimatedValue ?? 0), 0);
        return {
          stage,
          leadCount: stageLeads.length,
          revenue: Number(stageRevenue.toFixed(2)),
          leads: stageLeads,
        };
      });

      res.json(successResponse({ board, totalLeads: leads.length }));
    } catch (error) {
      next(error);
    }
  }
);

router.patch(
  '/pipeline/:leadId/stage',
  validate(
    z.object({
      params: z.object({ leadId: z.string().uuid() }),
      body: z.object({
        status: z.enum(['NEW', 'CONTACTED', 'SITE_VISIT_SCHEDULED', 'BID_SENT', 'WON', 'LOST']),
      }),
    })
  ),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const lead = await prisma.lead.findFirst({
        where: { id: req.params.leadId, businessId: req.user!.businessId },
      });
      if (!lead) throw ApiError.notFound('Lead');

      const updated = await prisma.lead.update({
        where: { id: lead.id },
        data: { status: req.body.status },
      });

      await prisma.activityLog.create({
        data: {
          businessId: req.user!.businessId,
          userId: req.user!.id,
          clientId: updated.clientId ?? undefined,
          action: 'pipeline_stage_changed',
          entityType: 'Lead',
          entityId: updated.id,
          metadata: { from: lead.status, to: updated.status },
        },
      });

      res.json(successResponse(updated));
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/communications/log',
  validate(
    z.object({
      body: z
        .object({
          clientId: z.string().uuid().optional(),
          leadId: z.string().uuid().optional(),
          channel: z.enum(['CALL', 'SMS', 'EMAIL']),
          direction: z.enum(['OUTBOUND', 'INBOUND']).default('OUTBOUND'),
          subject: z.string().optional(),
          message: z.string().min(1),
        })
        .refine((value) => value.clientId || value.leadId, 'clientId or leadId is required'),
    })
  ),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const log = await prisma.activityLog.create({
        data: {
          businessId: req.user!.businessId,
          userId: req.user!.id,
          clientId: req.body.clientId,
          action: `communication_${String(req.body.channel).toLowerCase()}`,
          entityType: req.body.leadId ? 'Lead' : 'Client',
          entityId: req.body.leadId ?? req.body.clientId,
          metadata: {
            direction: req.body.direction,
            subject: req.body.subject,
            message: req.body.message,
          },
        },
      });

      res.status(201).json(successResponse(log));
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/communications/reminders',
  validate(
    z.object({
      body: z.object({
        clientId: z.string().uuid(),
        title: z.string().min(1),
        body: z.string().min(1),
        remindAt: z.string().datetime(),
        smsBody: z.string().optional(),
      }),
    })
  ),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const notification = await prisma.notification.create({
        data: {
          businessId: req.user!.businessId,
          userId: req.user!.id,
          title: req.body.title,
          body: req.body.body,
          type: 'appointment_reminder',
          entityType: 'Client',
          entityId: req.body.clientId,
          sentAt: new Date(req.body.remindAt),
        },
      });

      await prisma.activityLog.create({
        data: {
          businessId: req.user!.businessId,
          userId: req.user!.id,
          clientId: req.body.clientId,
          action: 'appointment_reminder_scheduled',
          entityType: 'Notification',
          entityId: notification.id,
          metadata: { remindAt: req.body.remindAt, smsBody: req.body.smsBody },
        },
      });

      res.status(201).json(successResponse(notification));
    } catch (error) {
      next(error);
    }
  }
);

router.post(
  '/communications/follow-up-sequence',
  validate(
    z.object({
      body: z.object({
        leadId: z.string().uuid(),
        bidSentAt: z.string().datetime(),
      }),
    })
  ),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const lead = await prisma.lead.findFirst({
        where: { id: req.body.leadId, businessId: req.user!.businessId },
      });
      if (!lead) throw ApiError.notFound('Lead');

      const bidSentAt = new Date(req.body.bidSentAt);
      const dayOffsets = [1, 3, 7];
      const notifications = await Promise.all(
        dayOffsets.map((offset) =>
          prisma.notification.create({
            data: {
              businessId: req.user!.businessId,
              userId: req.user!.id,
              title: `Bid follow-up Day ${offset}`,
              body: `Follow up with ${lead.firstName} ${lead.lastName} about their bid.`,
              type: 'bid_follow_up',
              entityType: 'Lead',
              entityId: lead.id,
              sentAt: new Date(bidSentAt.getTime() + offset * 24 * 60 * 60 * 1000),
            },
          })
        )
      );

      res.status(201).json(successResponse(notifications));
    } catch (error) {
      next(error);
    }
  }
);

export default router;
