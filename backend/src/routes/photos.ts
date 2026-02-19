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
    mimeType: z.string().regex(/^image\//),
    category: z.enum(['BEFORE', 'DURING', 'AFTER', 'SURFACE_CONDITION', 'DAMAGE', 'MARKETING', 'DOCUMENT']).optional(),
  }),
});

const recordPhotoSchema = z.object({
  body: z.object({
    s3Key: z.string().min(1),
    url: z.string().url(),
    fileName: z.string().min(1),
    mimeType: z.string(),
    fileSizeBytes: z.number().int().positive().optional(),
    category: z.enum(['BEFORE', 'DURING', 'AFTER', 'SURFACE_CONDITION', 'DAMAGE', 'MARKETING', 'DOCUMENT']).optional(),
    jobId: z.string().uuid().optional(),
    clientId: z.string().uuid().optional(),
    caption: z.string().optional(),
    latitude: z.number().optional(),
    longitude: z.number().optional(),
    takenAt: z.string().datetime().optional(),
    isProposalReady: z.boolean().optional(),
  }),
});

// ─── POST /photos/upload-url ──────────────────────────────────────────────────
// Returns a pre-signed S3 URL for direct iOS → S3 upload.
router.post('/upload-url', validate(uploadUrlSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { fileName, mimeType } = req.body as { fileName: string; mimeType: string };
    const businessId = req.user!.businessId;
    const s3Key = `businesses/${businessId}/photos/${Date.now()}-${fileName.replace(/[^a-zA-Z0-9.\-_]/g, '_')}`;

    // TODO: const signedUrl = await s3.getSignedUrlPromise('putObject', { Bucket, Key, ContentType, Expires })
    const mockSignedUrl = `https://${process.env.AWS_S3_BUCKET ?? 'epoxybidpro-media'}.s3.amazonaws.com/${s3Key}?presigned=mock`;

    res.json(successResponse({ uploadUrl: mockSignedUrl, s3Key }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /photos/record ──────────────────────────────────────────────────────
// Records photo metadata after the iOS app has uploaded directly to S3.
router.post('/record', validate(recordPhotoSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const photo = await prisma.photo.create({
      data: { ...req.body as object, businessId: req.user!.businessId },
    });
    res.status(201).json(successResponse(photo));
  } catch (error) {
    next(error);
  }
});

// ─── GET /photos?jobId=&clientId= ─────────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { jobId, clientId, category, page = '1', limit = '50' } = req.query as Record<string, string>;
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    const where = {
      businessId: req.user!.businessId,
      ...(jobId && { jobId }),
      ...(clientId && { clientId }),
      ...(category && { category: category as never }),
    };

    const [photos, total] = await Promise.all([
      prisma.photo.findMany({
        where,
        skip: (pageNum - 1) * limitNum,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.photo.count({ where }),
    ]);

    res.json(paginatedResponse(photos, total, pageNum, limitNum));
  } catch (error) {
    next(error);
  }
});

// ─── PATCH /photos/:id ────────────────────────────────────────────────────────
router.patch('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const photo = await prisma.photo.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!photo) throw ApiError.notFound('Photo');

    const { caption, isProposalReady, category } = req.body as {
      caption?: string; isProposalReady?: boolean; category?: never;
    };

    const updated = await prisma.photo.update({
      where: { id: req.params.id },
      data: { caption, isProposalReady, category },
    });
    res.json(successResponse(updated));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /photos/:id ───────────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const photo = await prisma.photo.findFirst({
      where: { id: req.params.id, businessId: req.user!.businessId },
    });
    if (!photo) throw ApiError.notFound('Photo');

    // TODO: delete from S3: await s3.deleteObject({ Bucket, Key: photo.s3Key }).promise()
    await prisma.photo.delete({ where: { id: req.params.id } });
    res.json(successResponse({ deleted: true }));
  } catch (error) {
    next(error);
  }
});

export default router;
