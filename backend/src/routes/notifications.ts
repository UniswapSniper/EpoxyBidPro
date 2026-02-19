import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

// ─── GET /notifications ───────────────────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 30;
    const unreadOnly = req.query.unreadOnly === 'true';

    const where = { userId, ...(unreadOnly && { isRead: false }) };

    const [total, notifications] = await Promise.all([
      prisma.notification.count({ where }),
      prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    const unreadCount = unreadOnly
      ? total
      : await prisma.notification.count({ where: { userId, isRead: false } });

    res.json({ ...paginatedResponse(notifications, total, page, limit), unreadCount });
  } catch (error) {
    next(error);
  }
});

// ─── PATCH /notifications/:id/read ───────────────────────────────────────────
router.patch('/:id/read', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;
    const note = await prisma.notification.findFirst({ where: { id: req.params.id, userId } });
    if (!note) throw ApiError.notFound('Notification not found');

    await prisma.notification.update({ where: { id: req.params.id }, data: { isRead: true, readAt: new Date() } });
    res.json(successResponse(null, 'Marked as read'));
  } catch (error) {
    next(error);
  }
});

// ─── POST /notifications/read-all ────────────────────────────────────────────
router.post('/read-all', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;
    const { count } = await prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
    res.json(successResponse({ updated: count }, 'All notifications marked as read'));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /notifications/:id ────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;
    const note = await prisma.notification.findFirst({ where: { id: req.params.id, userId } });
    if (!note) throw ApiError.notFound('Notification not found');

    await prisma.notification.delete({ where: { id: req.params.id } });
    res.json(successResponse(null, 'Notification deleted'));
  } catch (error) {
    next(error);
  }
});

// ─── POST /notifications/register-device ─────────────────────────────────────
// Register or update an iOS FCM token for push notifications
router.post(
  '/register-device',
  validate(z.object({ fcmToken: z.string().min(1), deviceId: z.string().optional() })),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user!.id;
      const { fcmToken } = req.body;

      const user = await prisma.user.findUnique({ where: { id: userId }, select: { fcmTokens: true } });
      if (!user) throw ApiError.notFound('User not found');

      const tokens: string[] = user.fcmTokens as string[];
      if (!tokens.includes(fcmToken)) {
        await prisma.user.update({
          where: { id: userId },
          data: { fcmTokens: [...tokens, fcmToken] },
        });
      }

      res.json(successResponse(null, 'Device registered for push notifications'));
    } catch (error) {
      next(error);
    }
  }
);

// ─── DELETE /notifications/deregister-device ─────────────────────────────────
router.delete(
  '/deregister-device',
  validate(z.object({ fcmToken: z.string().min(1) })),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user!.id;
      const { fcmToken } = req.body;

      const user = await prisma.user.findUnique({ where: { id: userId }, select: { fcmTokens: true } });
      if (!user) throw ApiError.notFound('User not found');

      const tokens = (user.fcmTokens as string[]).filter((t) => t !== fcmToken);
      await prisma.user.update({ where: { id: userId }, data: { fcmTokens: tokens } });

      res.json(successResponse(null, 'Device deregistered'));
    } catch (error) {
      next(error);
    }
  }
);

// ─── POST /notifications/send ─────────────────────────────────────────────────
// Internal trigger: create a notification record and fan out a push via FCM.
// Targets: a single userId, or all users in the business (omit userId).
router.post(
  '/send',
  validate(
    z.object({
      body: z.object({
        userId: z.string().uuid().optional(),
        title: z.string().min(1).max(100),
        body: z.string().min(1).max(500),
        type: z.string().min(1),                // e.g. "invoice_overdue" | "quote_viewed"
        entityType: z.string().optional(),       // e.g. "Invoice" | "Bid" | "Job"
        entityId: z.string().uuid().optional(),  // ID of the related record
        data: z.record(z.string()).optional(),   // Extra key-value pairs for deep link
      }),
    })
  ),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const businessId = req.user!.businessId;
      const { userId, title, body: bodyText, type, entityType, entityId, data } = req.body as {
        userId?: string;
        title: string;
        body: string;
        type: string;
        entityType?: string;
        entityId?: string;
        data?: Record<string, string>;
      };

      // Determine target users
      const userFilter = userId
        ? { id: userId, businessId }
        : { businessId };

      const targetUsers = await prisma.user.findMany({
        where: userFilter,
        select: { id: true, fcmTokens: true },
      });

      if (targetUsers.length === 0) throw ApiError.notFound('No target users found');

      // Persist notification records for each target user
      const created = await prisma.$transaction(
        targetUsers.map((u) =>
          prisma.notification.create({
            data: {
              businessId,
              userId: u.id,
              title,
              body: bodyText,
              type,
              entityType,
              entityId,
              sentAt: new Date(),
            },
          })
        )
      );

      // Fan-out push notifications
      // TODO: initialize Firebase Admin SDK and call admin.messaging().sendEachForMulticast()
      // For now we collect all FCM tokens and log the intent.
      const allTokens = targetUsers.flatMap((u) => u.fcmTokens as string[]);
      if (allTokens.length > 0) {
        // Placeholder: replace with real Firebase push call
        // await admin.messaging().sendEachForMulticast({
        //   tokens: allTokens,
        //   notification: { title, body: bodyText },
        //   data: { type, entityType: entityType ?? '', entityId: entityId ?? '', ...data },
        // });
        logger.info(`[FCM] Would push to ${allTokens.length} device(s): "${title}"`);
      }

      res.status(201).json(
        successResponse({
          sent: created.length,
          deviceCount: allTokens.length,
          notifications: created.map((n) => ({ id: n.id, userId: n.userId })),
        })
      );
    } catch (error) {
      next(error);
    }
  }
);

export default router;
