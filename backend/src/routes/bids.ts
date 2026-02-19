import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { logger } from '../utils/logger';
import { computeTieredPricing } from '../services/bidPricingEngine';
import { getAiBidSuggestions } from '../services/aiBidService';
import { generateAndUploadProposal, type ProposalBid } from '../services/proposalService';
import { sendProposalEmail, sendSignedConfirmationEmail } from '../services/emailService';

const router = Router();
router.use(authenticate);

// ─── Schemas ─────────────────────────────────────────────────────────────────

const createBidSchema = z.object({
  body: z.object({
    clientId: z.string().uuid().optional(),
    measurementId: z.string().uuid().optional(),
    title: z.string().min(1),
    tier: z.enum(['GOOD', 'BETTER', 'BEST']).optional(),
    coatingSystem: z.enum(['SINGLE_COAT_CLEAR', 'TWO_COAT_FLAKE', 'FULL_METALLIC', 'QUARTZ', 'POLYASPARTIC', 'COMMERCIAL_GRADE', 'CUSTOM']).optional(),
    surfaceCondition: z.enum(['EXCELLENT', 'GOOD', 'FAIR', 'POOR']).optional(),
    totalSqFt: z.number().nonnegative().optional(),
    executiveSummary: z.string().optional(),
    scopeNotes: z.string().optional(),
    validUntil: z.string().datetime().optional(),
    notes: z.string().optional(),
    lineItems: z.array(z.object({
      areaId: z.string().uuid().optional(),
      materialId: z.string().uuid().optional(),
      category: z.string(),
      description: z.string(),
      quantity: z.number().positive(),
      unit: z.string().optional(),
      unitCost: z.number().nonneg(),
      markup: z.number().nonneg().optional(),
      order: z.number().int().optional(),
      isVisible: z.boolean().optional(),
    })).optional(),
  }),
});

const updateBidSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: createBidSchema.shape.body.partial(),
});

const sendBidSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: z.object({
    deliveryMethod: z.enum(['email', 'sms', 'both']).default('email'),
    customMessage: z.string().optional(),
  }),
});

const signBidSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: z.object({
    signerName: z.string().min(1),
    signerEmail: z.string().email().optional(),
    dataUrl: z.string().min(1), // Base64 signature image
    signerIp: z.string().optional(),
  }),
});

const aiSuggestSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: z.object({
    marketContext: z.string().optional(),
  }),
});

const pricePreviewSchema = z.object({
  body: z.object({
    totalSqFt: z.number().nonnegative(),
    estimatedHours: z.number().nonnegative().default(8),
    crewCount: z.number().int().positive().default(1),
    tier: z.enum(['GOOD', 'BETTER', 'BEST']).default('BETTER'),
    coatingSystem: z.enum(['SINGLE_COAT_CLEAR', 'TWO_COAT_FLAKE', 'FULL_METALLIC', 'QUARTZ', 'POLYASPARTIC', 'COMMERCIAL_GRADE', 'CUSTOM']).optional(),
    surfaceCondition: z.enum(['EXCELLENT', 'GOOD', 'FAIR', 'POOR']).optional(),
    prepComplexity: z.enum(['LIGHT', 'STANDARD', 'HEAVY']).optional(),
    accessDifficulty: z.enum(['EASY', 'NORMAL', 'DIFFICULT']).optional(),
    isComplexLayout: z.boolean().optional(),
    materialItems: z.array(
      z.object({
        label: z.string().min(1),
        sqFt: z.number().positive(),
        coverageRate: z.number().positive(),
        costPerUnit: z.number().positive(),
        numCoats: z.number().int().positive().default(1),
      })
    ).default([]),
  }),
});

const biddingSettingsSchema = z.object({
  body: z.object({
    laborRate: z.number().nonnegative().optional(),
    overheadRate: z.number().nonnegative().optional(),
    defaultMarkup: z.number().nonnegative().optional(),
    defaultMargin: z.number().nonnegative().optional(),
    taxRate: z.number().nonnegative().optional(),
    mobilizationFee: z.number().nonnegative().optional(),
    minimumJobPrice: z.number().nonnegative().optional(),
    wasteFactorStd: z.number().nonnegative().optional(),
    wasteFactorCpx: z.number().nonnegative().optional(),
  }),
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function assertBidOwner(bidId: string, businessId: string): Promise<void> {
  const bid = await prisma.bid.findFirst({ where: { id: bidId, businessId } });
  if (!bid) throw ApiError.notFound('Bid');
}

function computeBidTotals(lineItems: Array<{
  unitCost: number; quantity: number; markup: number; totalCost: number; totalPrice: number;
}>): { materialCost: number; laborCost: number; subtotal: number; markup: number; totalPrice: number } {
  const subtotal = lineItems.reduce((sum, li) => sum + li.totalCost, 0);
  const markupTotal = lineItems.reduce((sum, li) => sum + (li.totalPrice - li.totalCost), 0);
  return {
    materialCost: 0, // calculated per category in full implementation
    laborCost: 0,
    subtotal,
    markup: markupTotal,
    totalPrice: subtotal + markupTotal,
  };
}

// ─── GET /bids ────────────────────────────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { page = '1', limit = '25', status, clientId } = req.query as Record<string, string>;
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    const where = {
      businessId: req.user!.businessId,
      ...(status && { status: status as never }),
      ...(clientId && { clientId }),
    };

    const [bids, total] = await Promise.all([
      prisma.bid.findMany({
        where,
        skip: (pageNum - 1) * limitNum,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true, bidNumber: true, version: true, status: true, title: true,
          tier: true, coatingSystem: true, totalSqFt: true, totalPrice: true,
          profitMargin: true, sentAt: true, signedAt: true, createdAt: true,
          client: { select: { id: true, firstName: true, lastName: true, company: true } },
        },
      }),
      prisma.bid.count({ where }),
    ]);

    res.json(paginatedResponse(bids, total, pageNum, limitNum));
  } catch (error) {
    next(error);
  }
});

// ─── GET /bids/:id ────────────────────────────────────────────────────────────
router.get('/:id([0-9a-fA-F-]{36})', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bid = await prisma.bid.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
      include: {
        client: true,
        measurement: { include: { areas: { orderBy: { order: 'asc' } } } },
        lineItems: { orderBy: { order: 'asc' }, include: { material: true } },
        signature: true,
        job: { select: { id: true, status: true, scheduledDate: true } },
        template: { select: { id: true, name: true } },
      },
    });
    if (!bid) throw ApiError.notFound('Bid');
    res.json(successResponse(bid));
  } catch (error) {
    next(error);
  }
});

// ─── GET /bids/settings/pricing ──────────────────────────────────────────────
router.get('/settings/pricing', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const business = await prisma.business.findUnique({
      where: { id: req.user!.businessId },
      select: {
        laborRate: true,
        overheadRate: true,
        defaultMarkup: true,
        defaultMargin: true,
        taxRate: true,
        mobilizationFee: true,
        minimumJobPrice: true,
        wasteFactorStd: true,
        wasteFactorCpx: true,
      },
    });
    if (!business) throw ApiError.notFound('Business');
    res.json(successResponse(business));
  } catch (error) {
    next(error);
  }
});

// ─── PUT /bids/settings/pricing ──────────────────────────────────────────────
router.put('/settings/pricing', validate(biddingSettingsSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const updated = await prisma.business.update({
      where: { id: req.user!.businessId },
      data: req.body,
      select: {
        laborRate: true,
        overheadRate: true,
        defaultMarkup: true,
        defaultMargin: true,
        taxRate: true,
        mobilizationFee: true,
        minimumJobPrice: true,
        wasteFactorStd: true,
        wasteFactorCpx: true,
      },
    });
    res.json(successResponse(updated));
  } catch (error) {
    next(error);
  }
});

// ─── POST /bids/pricing/preview ───────────────────────────────────────────────
router.post('/pricing/preview', validate(pricePreviewSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const business = await prisma.business.findUnique({
      where: { id: req.user!.businessId },
      select: {
        laborRate: true,
        overheadRate: true,
        defaultMarkup: true,
        defaultMargin: true,
        taxRate: true,
        mobilizationFee: true,
        minimumJobPrice: true,
        wasteFactorStd: true,
        wasteFactorCpx: true,
      },
    });
    if (!business) throw ApiError.notFound('Business');

    const pricing = computeTieredPricing(req.body, business);
    res.json(successResponse(pricing));
  } catch (error) {
    next(error);
  }
});

// ─── POST /bids ────────────────────────────────────────────────────────────────
router.post('/', validate(createBidSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const { lineItems, ...rest } = req.body as {
      lineItems?: Array<{
        areaId?: string; materialId?: string; category: string; description: string;
        quantity: number; unit?: string; unitCost: number; markup?: number; order?: number; isVisible?: boolean;
      }>;
      clientId?: string; measurementId?: string; title: string;
      tier?: string; coatingSystem?: string; surfaceCondition?: string;
      totalSqFt?: number; validUntil?: string; notes?: string;
    };

    // Auto-increment bid number
    const business = await prisma.business.update({
      where: { id: businessId },
      data: { nextBidNum: { increment: 1 } },
      select: { nextBidNum: true, bidPrefix: true },
    });
    const bidNumber = `${business.bidPrefix}-${business.nextBidNum - 1}`;

    const bid = await prisma.bid.create({
      data: {
        businessId,
        bidNumber,
        ...rest,
        ...(lineItems && {
          lineItems: {
            create: lineItems.map((li, i) => ({
              ...li,
              order: li.order ?? i,
              totalCost: li.quantity * li.unitCost,
              totalPrice: li.quantity * li.unitCost * (1 + (li.markup ?? 0)),
            })),
          },
        }),
      },
      include: { lineItems: { orderBy: { order: 'asc' } } },
    });

    logger.info(`Bid ${bidNumber} created for business ${businessId}`);
    res.status(201).json(successResponse(bid));
  } catch (error) {
    next(error);
  }
});

// ─── PUT /bids/:id ────────────────────────────────────────────────────────────
router.put('/:id', validate(updateBidSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    await assertBidOwner(req.params.id, req.user!.businessId);
    const { lineItems, ...rest } = req.body as { lineItems?: unknown[]; [key: string]: unknown };
    const updated = await prisma.bid.update({
      where: { id: req.params.id },
      data: rest as never,
      include: { lineItems: { orderBy: { order: 'asc' } } },
    });
    res.json(successResponse(updated));
  } catch (error) {
    next(error);
  }
});

// ─── POST /bids/:id/send ──────────────────────────────────────────────────────
// Generates a PDF proposal, uploads to S3, emails to client, marks status SENT.
router.post('/:id/send', validate(sendBidSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    await assertBidOwner(req.params.id, businessId);

    const { deliveryMethod, customMessage } = req.body as {
      deliveryMethod: 'email' | 'sms' | 'both';
      customMessage?: string;
    };

    // Load full bid data needed for PDF generation
    const bid = await prisma.bid.findFirst({
      where: { id: req.params.id, businessId },
      include: {
        client: true,
        measurement: { include: { areas: { orderBy: { order: 'asc' } } } },
        lineItems: { where: { isVisible: true }, orderBy: { order: 'asc' }, include: { material: true } },
      },
    });
    if (!bid) throw ApiError.notFound('Bid');
    if (!bid.clientId || !bid.client) throw ApiError.badRequest('Bid must have an associated client to send');
    if (!bid.client.email && deliveryMethod !== 'sms') {
      throw ApiError.badRequest('Client does not have an email address');
    }

    // Load business branding
    const business = await prisma.business.findUnique({
      where: { id: businessId },
      select: {
        name: true, phone: true, email: true, website: true,
        address: true, city: true, state: true, zip: true,
        logoUrl: true, brandColor: true, accentColor: true,
        licenseNumber: true, warrantyText: true, termsText: true,
        aboutText: true, quoteFooter: true,
      },
    });
    if (!business) throw ApiError.notFound('Business');

    // Generate and upload PDF
    const proposalBidData: ProposalBid = {
      id: bid.id,
      bidNumber: bid.bidNumber,
      version: bid.version,
      title: bid.title,
      executiveSummary: bid.executiveSummary,
      scopeNotes: bid.scopeNotes,
      validUntil: bid.validUntil,
      totalSqFt: bid.totalSqFt,
      coatingSystem: bid.coatingSystem,
      materialCost: bid.materialCost,
      laborCost: bid.laborCost,
      overheadCost: bid.overheadCost,
      mobilizationFee: bid.mobilizationFee,
      subtotal: bid.subtotal,
      markup: bid.markup,
      taxAmount: bid.taxAmount,
      totalPrice: bid.totalPrice,
      estimatedDays: bid.estimatedDays,
      tier: bid.tier,
      aiRiskFlags: bid.aiRiskFlags,
      aiUpsells: bid.aiUpsells,
      lineItems: bid.lineItems.map(li => ({
        category: li.category,
        description: li.description,
        quantity: li.quantity,
        unit: li.unit,
        unitCost: li.unitCost,
        totalCost: li.totalCost,
        totalPrice: li.totalPrice,
        isVisible: li.isVisible,
      })),
      client: bid.client,
      measurement: bid.measurement
        ? {
            name: bid.measurement.name,
            totalSqFt: bid.measurement.totalSqFt,
            areas: bid.measurement.areas.map(a => ({ label: a.label, sqFt: a.sqFt })),
          }
        : null,
    };

    const pdfUrl = await generateAndUploadProposal(proposalBidData, {
      name: business.name,
      phone: business.phone,
      email: business.email,
      website: business.website,
      address: business.address,
      city: business.city,
      state: business.state,
      zip: business.zip,
      logoUrl: business.logoUrl,
      brandColor: business.brandColor,
      accentColor: business.accentColor,
      licenseNumber: business.licenseNumber,
      warranty: business.warrantyText,
      terms: business.termsText,
      about: business.aboutText,
      quoteFooter: business.quoteFooter,
    });

    // Send email if requested
    if ((deliveryMethod === 'email' || deliveryMethod === 'both') && bid.client.email) {
      await sendProposalEmail({
        toEmail: bid.client.email,
        toName: [bid.client.firstName, bid.client.lastName].join(' ').trim(),
        fromBusinessName: business.name,
        bidNumber: bid.bidNumber,
        pdfUrl,
        customMessage,
      });
    }

    // Update bid status and PDF URL
    const updated = await prisma.bid.update({
      where: { id: req.params.id },
      data: { status: 'SENT', sentAt: new Date(), pdfUrl, pdfGeneratedAt: new Date() },
    });

    logger.info(`Bid ${bid.bidNumber} sent to client ${bid.client.email ?? 'n/a'}`);
    res.json(successResponse({
      sent: true,
      bidNumber: updated.bidNumber,
      sentAt: updated.sentAt,
      pdfUrl,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /bids/:id/sign ──────────────────────────────────────────────────────
// Records client signature and marks bid as SIGNED. Sends confirmation email.
router.post('/:id/sign', validate(signBidSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    await assertBidOwner(req.params.id, req.user!.businessId);
    const { signerName, signerEmail, dataUrl, signerIp } = req.body as {
      signerName: string; signerEmail?: string; dataUrl: string; signerIp?: string;
    };

    const bid = await prisma.bid.findFirst({
      where: { id: req.params.id },
      include: { client: { select: { firstName: true, lastName: true, email: true } } },
    });
    if (!bid) throw ApiError.notFound('Bid');

    const [updatedBid] = await prisma.$transaction([
      prisma.bid.update({
        where: { id: req.params.id },
        data: { status: 'SIGNED', signedAt: new Date() },
      }),
      prisma.bidSignature.create({
        data: {
          bidId: req.params.id,
          signerName,
          signerEmail,
          dataUrl,
          signerIp: signerIp ?? req.ip,
        },
      }),
    ]);

    // Send signed confirmation email if client has an email
    const emailTarget = signerEmail ?? bid.client?.email;
    if (emailTarget) {
      const business = await prisma.business.findUnique({
        where: { id: req.user!.businessId },
        select: { name: true },
      });
      await sendSignedConfirmationEmail({
        toEmail: emailTarget,
        toName: signerName,
        fromBusinessName: business?.name ?? 'Your Contractor',
        bidNumber: bid.bidNumber,
        totalPrice: bid.totalPrice,
      }).catch(err => logger.warn(`Signed confirmation email failed: ${String(err)}`));
    }

    logger.info(`Bid ${req.params.id} signed by ${signerName}`);
    res.json(successResponse({ signed: true, signedAt: updatedBid.signedAt }));
  } catch (error) {
    next(error);
  }
});

// ─── GET /bids/:id/pdf ────────────────────────────────────────────────────────
// Returns the bid PDF URL, regenerating if not already generated.
router.get('/:id/pdf', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const bid = await prisma.bid.findFirst({
      where: { id: req.params.id, businessId },
      include: {
        client: true,
        measurement: { include: { areas: { orderBy: { order: 'asc' } } } },
        lineItems: { where: { isVisible: true }, orderBy: { order: 'asc' } },
      },
    });
    if (!bid) throw ApiError.notFound('Bid');

    // Return cached URL if already generated
    if (bid.pdfUrl) {
      return res.json(successResponse({ pdfUrl: bid.pdfUrl, bidNumber: bid.bidNumber, cached: true }));
    }

    // Load business branding for generation
    const business = await prisma.business.findUnique({
      where: { id: businessId },
      select: {
        name: true, phone: true, email: true, website: true,
        address: true, city: true, state: true, zip: true,
        logoUrl: true, brandColor: true, accentColor: true,
        licenseNumber: true, warrantyText: true, termsText: true,
        aboutText: true, quoteFooter: true,
      },
    });
    if (!business) throw ApiError.notFound('Business');

    const pdfUrl = await generateAndUploadProposal(
      {
        id: bid.id,
        bidNumber: bid.bidNumber,
        version: bid.version,
        title: bid.title,
        executiveSummary: bid.executiveSummary,
        scopeNotes: bid.scopeNotes,
        validUntil: bid.validUntil,
        totalSqFt: bid.totalSqFt,
        coatingSystem: bid.coatingSystem,
        materialCost: bid.materialCost,
        laborCost: bid.laborCost,
        overheadCost: bid.overheadCost,
        mobilizationFee: bid.mobilizationFee,
        subtotal: bid.subtotal,
        markup: bid.markup,
        taxAmount: bid.taxAmount,
        totalPrice: bid.totalPrice,
        estimatedDays: bid.estimatedDays,
        tier: bid.tier,
        aiRiskFlags: bid.aiRiskFlags,
        aiUpsells: bid.aiUpsells,
        lineItems: bid.lineItems.map(li => ({
          category: li.category,
          description: li.description,
          quantity: li.quantity,
          unit: li.unit,
          unitCost: li.unitCost,
          totalCost: li.totalCost,
          totalPrice: li.totalPrice,
          isVisible: li.isVisible,
        })),
        client: bid.client,
        measurement: bid.measurement
          ? {
              name: bid.measurement.name,
              totalSqFt: bid.measurement.totalSqFt,
              areas: bid.measurement.areas.map(a => ({ label: a.label, sqFt: a.sqFt })),
            }
          : null,
      },
      {
        name: business.name,
        phone: business.phone,
        email: business.email,
        website: business.website,
        address: business.address,
        city: business.city,
        state: business.state,
        zip: business.zip,
        logoUrl: business.logoUrl,
        brandColor: business.brandColor,
        accentColor: business.accentColor,
        licenseNumber: business.licenseNumber,
        warranty: business.warrantyText,
        terms: business.termsText,
        about: business.aboutText,
        quoteFooter: business.quoteFooter,
      },
    );

    await prisma.bid.update({
      where: { id: req.params.id },
      data: { pdfUrl, pdfGeneratedAt: new Date() },
    });

    return res.json(successResponse({ pdfUrl, bidNumber: bid.bidNumber, cached: false }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /bids/:id/viewed ────────────────────────────────────────────────────
// Called when a client opens the bid PDF or view link; updates status to VIEWED.
router.post('/:id/viewed', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bid = await prisma.bid.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!bid) throw ApiError.notFound('Bid');

    // Only mark VIEWED if currently SENT (don't regress from SIGNED)
    if (bid.status === 'SENT') {
      await prisma.bid.update({
        where: { id: req.params.id },
        data: { status: 'VIEWED', viewedAt: new Date() },
      });
      logger.info(`Bid ${bid.bidNumber} viewed by client`);
    }

    res.json(successResponse({ viewed: true, viewedAt: bid.viewedAt ?? new Date() }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /bids/:id/decline ───────────────────────────────────────────────────
// Client declines the bid; records the reason and sets status to DECLINED.
router.post('/:id/decline', async (req: Request, res: Response, next: NextFunction) => {
  try {
    await assertBidOwner(req.params.id, req.user!.businessId);
    const { reason } = req.body as { reason?: string };

    const bid = await prisma.bid.update({
      where: { id: req.params.id },
      data: {
        status: 'DECLINED',
        declinedAt: new Date(),
        declinedReason: reason ?? null,
      },
    });

    logger.info(`Bid ${bid.bidNumber} declined`);
    res.json(successResponse({ declined: true, declinedAt: bid.declinedAt }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /bids/:id/ai-suggest ────────────────────────────────────────────────
// Calls OpenAI to generate AI pricing suggestions, risk flags, and upsells.
router.post('/:id/ai-suggest', validate(aiSuggestSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bid = await prisma.bid.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
      include: {
        measurement: { include: { areas: true } },
        lineItems: true,
        client: { select: { type: true, city: true, state: true } },
      },
    });
    if (!bid) throw ApiError.notFound('Bid');

    const suggestions = await getAiBidSuggestions({
      bid: {
        id: bid.id,
        totalSqFt: bid.totalSqFt,
        coatingSystem: bid.coatingSystem,
        surfaceCondition: bid.surfaceCondition,
        totalPrice: bid.totalPrice,
      },
      client: bid.client,
      marketContext: req.body.marketContext,
    });

    await prisma.bid.update({
      where: { id: req.params.id },
      data: {
        aiSuggestions: suggestions,
        aiRiskFlags: suggestions.riskFlags,
        aiUpsells: suggestions.upsells,
      },
    });

    res.json(successResponse({ suggestions }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /bids/:id/convert-to-job ───────────────────────────────────────────
// Converts a signed bid into a scheduled job.
router.post('/:id/convert-to-job', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bid = await prisma.bid.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!bid) throw ApiError.notFound('Bid');
    if (bid.status !== 'SIGNED') {
      throw ApiError.badRequest('Only a signed bid can be converted to a job');
    }
    if (!bid.clientId) throw ApiError.badRequest('Bid must have an associated client');

    const job = await prisma.job.create({
      data: {
        businessId: bid.businessId,
        clientId: bid.clientId,
        bidId: bid.id,
        title: bid.title,
        totalSqFt: bid.totalSqFt,
        coatingSystem: bid.coatingSystem,
      },
    });

    logger.info(`Bid ${bid.bidNumber} converted to job ${job.id}`);
    res.status(201).json(successResponse(job));
  } catch (error) {
    next(error);
  }
});

// ─── POST /bids/:id/clone ─────────────────────────────────────────────────────
router.post('/:id/clone', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const original = await prisma.bid.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
      include: { lineItems: true },
    });
    if (!original) throw ApiError.notFound('Bid');

    const business = await prisma.business.update({
      where: { id: req.user!.businessId },
      data: { nextBidNum: { increment: 1 } },
      select: { nextBidNum: true, bidPrefix: true },
    });
    const newBidNumber = `${business.bidPrefix}-${business.nextBidNum - 1}`;

    const { id, bidNumber, status, sentAt, viewedAt, signedAt, declinedAt, declinedReason,
            pdfUrl, aiSuggestions, aiRiskFlags, aiUpsells, createdAt, updatedAt,
            lineItems, ...rest } = original;

    const cloned = await prisma.bid.create({
      data: {
        ...rest,
        bidNumber: newBidNumber,
        status: 'DRAFT',
        version: 1,
        lineItems: {
          create: lineItems.map(({ id: _id, bidId: _b, createdAt: _c, updatedAt: _u, ...li }) => li),
        },
      },
      include: { lineItems: true },
    });

    res.status(201).json(successResponse(cloned));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /bids/:id ─────────────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bid = await prisma.bid.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!bid) throw ApiError.notFound('Bid');
    if (bid.status === 'SIGNED') {
      throw ApiError.badRequest('Cannot delete a signed bid. Archive it instead.');
    }
    await prisma.bid.delete({ where: { id: req.params.id } });
    res.json(successResponse({ deleted: true }));
  } catch (error) {
    next(error);
  }
});

// ─── Unused helper to satisfy TS (will expand in pricing service) ─────────────
void computeBidTotals;

export default router;
