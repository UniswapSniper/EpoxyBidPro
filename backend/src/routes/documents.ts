import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

const uploadUrlSchema = z.object({
  body: z.object({
    fileName: z.string().min(1),
    mimeType: z.string().min(1),
    type: z.enum(['SIGNED_QUOTE', 'INVOICE', 'WARRANTY', 'PERMIT', 'SUPPLIER_QUOTE', 'OTHER']),
    jobId: z.string().uuid().optional(),
  }),
});

const recordDocumentSchema = z.object({
  body: z.object({
    name: z.string().min(1),
    type: z.enum(['SIGNED_QUOTE', 'INVOICE', 'WARRANTY', 'PERMIT', 'SUPPLIER_QUOTE', 'OTHER']),
    s3Key: z.string().min(1),
    url: z.string().url(),
    mimeType: z.string().min(1),
    fileSize: z.number().int().positive().optional(),
    jobId: z.string().uuid().optional(),
  }),
});

router.post('/upload-url', validate(uploadUrlSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { fileName, mimeType, type } = req.body as { fileName: string; mimeType: string; type: string };
    const key = `businesses/${req.user!.businessId}/documents/${type.toLowerCase()}/${Date.now()}-${fileName.replace(/[^a-zA-Z0-9.\-_]/g, '_')}`;
    const uploadUrl = `https://${process.env.AWS_S3_BUCKET ?? 'epoxybidpro-media'}.s3.amazonaws.com/${key}?presigned=mock&contentType=${encodeURIComponent(mimeType)}`;

    res.json(successResponse({ uploadUrl, s3Key: key }));
  } catch (error) {
    next(error);
  }
});

router.post('/record', validate(recordDocumentSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const payload = req.body as {
      name: string;
      type: string;
      s3Key: string;
      url: string;
      mimeType: string;
      fileSize?: number;
      jobId?: string;
    };

    const document = await prisma.document.create({
      data: {
        businessId: req.user!.businessId,
        ...payload,
      },
    });

    res.status(201).json(successResponse(document));
  } catch (error) {
    next(error);
  }
});

router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { page = '1', limit = '25', type, jobId } = req.query as Record<string, string>;
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    const where = {
      businessId: req.user!.businessId,
      ...(type && { type }),
      ...(jobId && { jobId }),
    };

    const [documents, total] = await Promise.all([
      prisma.document.findMany({
        where,
        skip: (pageNum - 1) * limitNum,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.document.count({ where }),
    ]);

    res.json(paginatedResponse(documents, total, pageNum, limitNum));
  } catch (error) {
    next(error);
  }
});

router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const document = await prisma.document.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!document) throw ApiError.notFound('Document');

    res.json(successResponse(document));
  } catch (error) {
    next(error);
  }
});

router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const document = await prisma.document.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!document) throw ApiError.notFound('Document');

    await prisma.document.delete({ where: { id: req.params.id } });
    res.json(successResponse({ deleted: true }));
  } catch (error) {
    next(error);
  }
});

export default router;
