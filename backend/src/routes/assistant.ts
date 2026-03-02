import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { getAssistantReply } from '../services/assistantService';
import { validate } from '../middleware/validate';

const router = Router();

const assistantChatSchema = z.object({
  body: z.object({
    message: z.string().min(1).max(2000),
    mode: z.enum(['chat', 'daily_briefing', 'follow_up_draft', 'invoice_reminder']).optional(),
    tone: z.enum(['concise', 'friendly', 'direct']).optional(),
    maxTokens: z.number().int().positive().max(2048).optional(),
    context: z
      .object({
        activeTab: z.string().max(64).optional(),
        businessName: z.string().max(128).optional(),
        metrics: z
          .object({
            leadCount: z.number().int().nonnegative().optional(),
            overdueFollowUps: z.number().int().nonnegative().optional(),
            draftBidCount: z.number().int().nonnegative().optional(),
            scheduledJobCount: z.number().int().nonnegative().optional(),
            overdueInvoiceCount: z.number().int().nonnegative().optional(),
            openInvoiceBalance: z.number().nonnegative().optional(),
          })
          .optional(),
      })
      .optional(),
  }),
});

router.post('/chat', validate(assistantChatSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { message, mode, tone, context, maxTokens } = req.body as {
      message: string;
      mode?: 'chat' | 'daily_briefing' | 'follow_up_draft' | 'invoice_reminder';
      tone?: 'concise' | 'friendly' | 'direct';
      context?: {
        activeTab?: string;
        businessName?: string;
        metrics?: {
          leadCount?: number;
          overdueFollowUps?: number;
          draftBidCount?: number;
          scheduledJobCount?: number;
          overdueInvoiceCount?: number;
          openInvoiceBalance?: number;
        };
      };
      maxTokens?: number;
    };

    const reply = await getAssistantReply({
      message,
      mode,
      tone,
      context,
      maxTokens,
    });
    res.status(200).json({ reply });
  } catch (error) {
    next(error);
  }
});

export default router;
