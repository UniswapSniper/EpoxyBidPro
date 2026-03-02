import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { getAssistantReply } from '../services/assistantService';
import { validate } from '../middleware/validate';

const router = Router();

const assistantChatSchema = z.object({
  body: z.object({
    message: z.string().min(1).max(2000),
    maxTokens: z.number().int().positive().max(2048).optional(),
    context: z
      .object({
        activeTab: z.string().max(64).optional(),
        businessName: z.string().max(128).optional(),
      })
      .optional(),
  }),
});

router.post('/chat', validate(assistantChatSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { message, context, maxTokens } = req.body as {
      message: string;
      context?: { activeTab?: string; businessName?: string };
      maxTokens?: number;
    };

    const reply = await getAssistantReply(message, context, maxTokens);
    res.status(200).json({ reply });
  } catch (error) {
    next(error);
  }
});

export default router;
