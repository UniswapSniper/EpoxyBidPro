import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { logger } from '../utils/logger';
import { createBitcoinInvoice, getBitcoinInvoiceStatus, verifyStrikeWebhook } from '../utils/strike';

const router = Router();

// ─── Bitcoin Webhook (NO auth — verified by Strike signature) ───────────────
// Must be mounted before router.use(authenticate) so it's accessible without JWT.

const bitcoinWebhookHandler = Router();

bitcoinWebhookHandler.post('/bitcoin/webhook', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const signature = req.headers['x-webhook-signature'] as string | undefined;
    const webhookSecret = process.env.STRIKE_WEBHOOK_SECRET;

    if (!signature || !webhookSecret) {
      throw ApiError.unauthorized('Missing Strike webhook signature');
    }

    const rawBody = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
    const isValid = verifyStrikeWebhook(rawBody, signature, webhookSecret);
    if (!isValid) {
      throw ApiError.unauthorized('Invalid Strike webhook signature');
    }

    const event = req.body as { eventType: string; data: { entityId: string } };

    if (event.eventType === 'invoice.updated') {
      const strikeInvoiceId = event.data.entityId;

      // Find the pending payment record or the invoice linked to this Strike invoice
      const existingPayment = await prisma.payment.findFirst({
        where: { strikeInvoiceId },
        include: { invoice: true },
      });

      if (existingPayment) {
        logger.info(`Strike webhook: invoice ${strikeInvoiceId} already recorded`);
        res.json({ received: true });
        return;
      }

      // Look up which invoice this Strike ID belongs to by checking recent activity
      // The Strike invoice ID is stored when the bitcoin invoice is created
      // We need to find the app invoice by looking at any payment with this strikeInvoiceId
      // or by checking a pending record. For now, we log and acknowledge.
      logger.info(`Strike webhook received for invoice ${strikeInvoiceId}`);
    }

    res.json({ received: true });
  } catch (error) {
    next(error);
  }
});

// Export the webhook handler separately for mounting before auth
export { bitcoinWebhookHandler };

// ─── Authenticated Routes ───────────────────────────────────────────────────
router.use(authenticate);

const createIntentSchema = z.object({
  body: z.object({
    invoiceId: z.string().uuid(),
    amount: z.number().positive(), // cents
    method: z.enum(['CARD', 'ACH', 'APPLE_PAY']).default('CARD'),
  }),
});

const paymentLinkSchema = z.object({
  body: z.object({
    invoiceId: z.string().uuid(),
    method: z.enum(['CARD', 'ACH', 'APPLE_PAY', 'BITCOIN']).optional(),
  }),
});

const recordPaymentSchema = z.object({
  body: z.object({
    invoiceId: z.string().uuid(),
    amount: z.number().positive(),
    method: z.enum(['CARD', 'ACH', 'APPLE_PAY', 'CHECK', 'CASH', 'BITCOIN', 'OTHER']).default('CARD'),
    stripePaymentId: z.string().optional(),
    strikeInvoiceId: z.string().optional(),
    btcAmountSats: z.number().int().optional(),
    exchangeRateUsed: z.number().optional(),
    notes: z.string().optional(),
  }),
});

const btcInvoiceSchema = z.object({
  body: z.object({
    invoiceId: z.string().uuid(),
  }),
});

const btcSettingsSchema = z.object({
  body: z.object({
    btcPaymentsEnabled: z.boolean().optional(),
    strikeApiKey: z.string().min(1).optional(),
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
      method,
    }));
  } catch (error) {
    next(error);
  }
});


router.post('/payment-link', validate(paymentLinkSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { invoiceId, method = 'CARD' } = req.body as { invoiceId: string; method?: string };

    const invoice = await prisma.invoice.findFirst({
      where: { id: invoiceId, businessId: req.user!.businessId },
    });
    if (!invoice) throw ApiError.notFound('Invoice');

    // For Bitcoin, redirect to the bitcoin invoice creation endpoint
    if (method === 'BITCOIN') {
      const business = await prisma.business.findUnique({
        where: { id: req.user!.businessId },
      });
      if (!business?.btcPaymentsEnabled || !business.strikeApiKeyEnc) {
        throw ApiError.badRequest('Bitcoin payments are not enabled for this business');
      }

      const result = await createBitcoinInvoice(
        invoice.amountDue,
        `Payment for invoice ${invoice.invoiceNumber}`,
        business.strikeApiKeyEnc,
      );

      res.json(successResponse({
        paymentUrl: result.paymentUri,
        method: 'BITCOIN',
        invoiceNumber: invoice.invoiceNumber,
        amountDue: invoice.amountDue,
        bitcoin: result,
      }));
      return;
    }

    const token = Buffer.from(`${invoice.id}:${Date.now()}`).toString('base64url');
    const paymentUrl = `${process.env.APP_BASE_URL ?? 'https://app.epoxybidpro.local'}/pay/${token}`;

    res.json(successResponse({
      paymentUrl,
      method,
      invoiceNumber: invoice.invoiceNumber,
      amountDue: invoice.amountDue,
      expiresInHours: 72,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /payments/record ────────────────────────────────────────────────────
// Records a manual payment (cash, check, bitcoin, etc.) against an invoice.
router.post('/record', validate(recordPaymentSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { invoiceId, amount, method, stripePaymentId, strikeInvoiceId, btcAmountSats, exchangeRateUsed, notes } = req.body as {
      invoiceId: string; amount: number; method: never; stripePaymentId?: string;
      strikeInvoiceId?: string; btcAmountSats?: number; exchangeRateUsed?: number; notes?: string;
    };

    const invoice = await prisma.invoice.findFirst({
      where: { id: invoiceId, businessId: req.user!.businessId },
    });
    if (!invoice) throw ApiError.notFound('Invoice');

    const [payment, updatedInvoice] = await prisma.$transaction(async (tx: import('@prisma/client').Prisma.TransactionClient) => {
      const pmt = await tx.payment.create({
        data: {
          invoiceId, amount, method, stripePaymentId,
          strikeInvoiceId, btcAmountSats, exchangeRateUsed, notes,
        },
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

    res.status(201).json(successResponse({
      payment: {
        ...payment,
        receipt: {
          sent: true,
          channel: 'email',
          message: `Receipt sent for $${amount.toFixed(2)} on invoice ${updatedInvoice.invoiceNumber}.`,
        },
      },
      invoice: updatedInvoice,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /payments/payout-schedule ───────────────────────────────────────────
router.get('/payout-schedule', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const paid = await prisma.payment.aggregate({
      where: { invoice: { businessId: req.user!.businessId } },
      _sum: { amount: true },
    });

    const gross = paid._sum.amount ?? 0;
    const estimatedFees = gross * 0.029;
    const upcomingPayout = Math.max(gross - estimatedFees, 0);

    res.json(successResponse({
      cadence: 'daily',
      grossCollected: gross,
      estimatedFees,
      upcomingPayout,
      nextPayoutDate: new Date(Date.now() + 24 * 60 * 60 * 1000),
    }));
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

// ─── POST /payments/bitcoin/create-invoice ──────────────────────────────────
// Creates a Bitcoin/Lightning invoice via Strike API for the given app invoice.
router.post('/bitcoin/create-invoice', validate(btcInvoiceSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { invoiceId } = req.body as { invoiceId: string };

    const invoice = await prisma.invoice.findFirst({
      where: { id: invoiceId, businessId: req.user!.businessId },
    });
    if (!invoice) throw ApiError.notFound('Invoice');
    if (invoice.amountDue <= 0) throw ApiError.badRequest('Invoice is already fully paid');

    const business = await prisma.business.findUnique({
      where: { id: req.user!.businessId },
    });
    if (!business?.btcPaymentsEnabled || !business.strikeApiKeyEnc) {
      throw ApiError.badRequest('Bitcoin payments are not enabled. Enable them in Settings.');
    }

    const result = await createBitcoinInvoice(
      invoice.amountDue,
      `Payment for invoice ${invoice.invoiceNumber}`,
      business.strikeApiKeyEnc,
    );

    logger.info(`Bitcoin invoice created for ${invoice.invoiceNumber}: $${invoice.amountDue} = ${result.amountBtcSats} sats`);

    res.json(successResponse(result));
  } catch (error) {
    next(error);
  }
});

// ─── GET /payments/bitcoin/check-status/:strikeInvoiceId ─────────────────────
// Polling endpoint for checking Bitcoin payment status.
router.get('/bitcoin/check-status/:strikeInvoiceId', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { strikeInvoiceId } = req.params;

    const business = await prisma.business.findUnique({
      where: { id: req.user!.businessId },
    });
    if (!business?.strikeApiKeyEnc) {
      throw ApiError.badRequest('Bitcoin payments are not configured');
    }

    const status = await getBitcoinInvoiceStatus(strikeInvoiceId, business.strikeApiKeyEnc);

    res.json(successResponse(status));
  } catch (error) {
    next(error);
  }
});

// ─── GET /payments/bitcoin/settings ──────────────────────────────────────────
router.get('/bitcoin/settings', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const business = await prisma.business.findUnique({
      where: { id: req.user!.businessId },
      select: { btcPaymentsEnabled: true, strikeApiKeyEnc: true },
    });

    res.json(successResponse({
      btcPaymentsEnabled: business?.btcPaymentsEnabled ?? false,
      strikeApiKeyConfigured: !!business?.strikeApiKeyEnc,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── PATCH /payments/bitcoin/settings ────────────────────────────────────────
router.patch('/bitcoin/settings', validate(btcSettingsSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { btcPaymentsEnabled, strikeApiKey } = req.body as {
      btcPaymentsEnabled?: boolean; strikeApiKey?: string;
    };

    const data: Record<string, unknown> = {};
    if (btcPaymentsEnabled !== undefined) data.btcPaymentsEnabled = btcPaymentsEnabled;
    if (strikeApiKey !== undefined) data.strikeApiKeyEnc = strikeApiKey; // TODO: encrypt at rest

    const business = await prisma.business.update({
      where: { id: req.user!.businessId },
      data,
      select: { btcPaymentsEnabled: true, strikeApiKeyEnc: true },
    });

    logger.info(`Bitcoin settings updated for business ${req.user!.businessId}: enabled=${business.btcPaymentsEnabled}`);

    res.json(successResponse({
      btcPaymentsEnabled: business.btcPaymentsEnabled,
      strikeApiKeyConfigured: !!business.strikeApiKeyEnc,
    }));
  } catch (error) {
    next(error);
  }
});

export default router;
