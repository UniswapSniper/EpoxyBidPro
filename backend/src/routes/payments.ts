import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { logger } from '../utils/logger';

const router = Router();
router.use(authenticate);

// Stripe webhook endpoint is intentionally NOT protected by JWT —
// it is verified by Stripe signature instead.
// Mount it before router.use(authenticate) in app.ts if needed.

const createIntentSchema = z.object({
  body: z.object({
    invoiceId: z.string().uuid(),
    amount: z.number().positive(), // cents
    method: z.enum(['CARD', 'ACH', 'APPLE_PAY']).default('CARD'),
  }),
});

const recordPaymentSchema = z.object({
  body: z.object({
    invoiceId: z.string().uuid(),
    amount: z.number().positive(),
    method: z.enum(['CARD', 'ACH', 'APPLE_PAY', 'CHECK', 'CASH', 'OTHER']).default('CARD'),
    stripePaymentId: z.string().optional(),
    notes: z.string().optional(),
  }),
});

// ─── POST /payments/create-intent ────────────────────────────────────────────
// Creates a Stripe PaymentIntent and returns the client_secret to the iOS app.
router.post('/create-intent', validate(createIntentSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { invoiceId, amount, method } = req.body as {
      invoiceId: string; amount: number; method: string;
    };

    const invoice = await prisma.invoice.findFirst({
      where: { id: invoiceId, businessId: req.user!.businessId },
    });
    if (!invoice) throw ApiError.notFound('Invoice');

    // TODO: initialize Stripe and create real PaymentIntent
    // const paymentIntent = await stripe.paymentIntents.create({ amount, currency: 'usd', ... })
    const mockClientSecret = `pi_mock_${Date.now()}_secret_${Math.random().toString(36).slice(2)}`;

    logger.info(`PaymentIntent created for invoice ${invoice.invoiceNumber}: $${amount / 100}`);
    res.json(successResponse({
      clientSecret: mockClientSecret,
      amount,
      currency: 'usd',
      invoiceNumber: invoice.invoiceNumber,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /payments/record ────────────────────────────────────────────────────
// Records a manual payment (cash, check, etc.) against an invoice.
router.post('/record', validate(recordPaymentSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { invoiceId, amount, method, stripePaymentId, notes } = req.body as {
      invoiceId: string; amount: number; method: never; stripePaymentId?: string; notes?: string;
    };

    const invoice = await prisma.invoice.findFirst({
      where: { id: invoiceId, businessId: req.user!.businessId },
    });
    if (!invoice) throw ApiError.notFound('Invoice');

    const [payment, updatedInvoice] = await prisma.$transaction(async (tx) => {
      const pmt = await tx.payment.create({
        data: { invoiceId, amount, method, stripePaymentId, notes },
      });

      const newAmountPaid = invoice.amountPaid + amount;
      const newAmountDue = Math.max(invoice.totalAmount - newAmountPaid, 0);
      const newStatus = newAmountDue === 0 ? 'PAID' : 'PARTIALLY_PAID';

      const inv = await tx.invoice.update({
        where: { id: invoiceId },
        data: {
          amountPaid: newAmountPaid,
          amountDue: newAmountDue,
          status: newStatus,
          paidAt: newStatus === 'PAID' ? new Date() : undefined,
        },
      });

      return [pmt, inv];
    });

    res.status(201).json(successResponse({ payment, invoice: updatedInvoice }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /payments/webhook ───────────────────────────────────────────────────
// Stripe webhook handler — verifies Stripe-Signature header.
// This route should be mounted RAW (no express.json()) for signature validation.
router.post('/webhook', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const sig = req.headers['stripe-signature'];
    if (!sig) throw ApiError.unauthorized('Missing Stripe signature');

    // TODO: const event = stripe.webhooks.constructEvent(req.rawBody, sig, process.env.STRIPE_WEBHOOK_SECRET!)
    // Handle event.type: 'payment_intent.succeeded', 'invoice.paid', etc.

    logger.info('Stripe webhook received');
    res.json({ received: true });
  } catch (error) {
    next(error);
  }
});

export default router;
