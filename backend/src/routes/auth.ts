import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse } from '../utils/apiError';
import { validate } from '../middleware/validate';
import { authenticate } from '../middleware/auth';
import { logger } from '../utils/logger';

const router = Router();

// ─── Schemas ─────────────────────────────────────────────────────────────────

const registerSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8).optional(),
    firstName: z.string().min(1),
    lastName: z.string().min(1),
    businessName: z.string().min(1),
    phone: z.string().optional(),
  }),
});

const loginSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(1),
  }),
});

const appleSignInSchema = z.object({
  body: z.object({
    identityToken: z.string(),
    firstName: z.string().optional(),
    lastName: z.string().optional(),
    email: z.string().email().optional(),
    businessName: z.string().optional(),
  }),
});

const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string(),
  }),
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

function generateTokens(userId: string, businessId: string, role: string): {
  accessToken: string;
  refreshToken: string;
} {
  const secret = process.env.JWT_SECRET!;
  const refreshSecret = process.env.JWT_REFRESH_SECRET!;

  const accessToken = jwt.sign({ userId, businessId, role }, secret, {
    expiresIn: process.env.JWT_EXPIRES_IN ?? '15m',
  });

  const refreshToken = jwt.sign({ userId, businessId, role }, refreshSecret, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '30d',
  });

  return { accessToken, refreshToken };
}

// ─── POST /auth/register ──────────────────────────────────────────────────────
router.post('/register', validate(registerSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password, firstName, lastName, businessName, phone } = req.body as {
      email: string;
      password?: string;
      firstName: string;
      lastName: string;
      businessName: string;
      phone?: string;
    };

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) throw ApiError.conflict('An account with this email already exists');

    const passwordHash = password ? await bcrypt.hash(password, 12) : null;
    const trialEndsAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000); // 14 days

    const business = await prisma.business.create({
      data: { name: businessName },
    });

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash: passwordHash ?? undefined,
        firstName,
        lastName,
        phone,
        businessId: business.id,
        plan: 'FREE_TRIAL',
        trialEndsAt,
      },
    });

    const { accessToken, refreshToken } = generateTokens(user.id, business.id, user.role);

    logger.info(`New user registered: ${user.email} (business: ${business.name})`);

    res.status(201).json(successResponse({
      user: { id: user.id, email: user.email, firstName, lastName, role: user.role },
      business: { id: business.id, name: business.name },
      accessToken,
      refreshToken,
      trialEndsAt,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /auth/login ──────────────────────────────────────────────────────
router.post('/login', validate(loginSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password } = req.body as { email: string; password: string };

    const user = await prisma.user.findUnique({
      where: { email },
      include: { business: { select: { id: true, name: true, logoUrl: true } } },
    });

    if (!user || !user.passwordHash) throw ApiError.unauthorized('Invalid email or password');
    if (!user.isActive) throw ApiError.unauthorized('Account is deactivated');

    const isValid = await bcrypt.compare(password, user.passwordHash);
    if (!isValid) throw ApiError.unauthorized('Invalid email or password');

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const { accessToken, refreshToken } = generateTokens(user.id, user.businessId, user.role);

    res.json(successResponse({
      user: { id: user.id, email: user.email, firstName: user.firstName, lastName: user.lastName, role: user.role },
      business: user.business,
      accessToken,
      refreshToken,
    }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /auth/apple ──────────────────────────────────────────────────────
router.post('/apple', validate(appleSignInSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    // TODO: Verify Apple identity token via Apple's public keys
    // For now, extract claims from the token payload (implement full JWKS verification)
    const { identityToken, firstName, lastName, email, businessName } = req.body as {
      identityToken: string;
      firstName?: string;
      lastName?: string;
      email?: string;
      businessName?: string;
    };

    // Decode without verification for scaffold — replace with appleSignIn.verifyToken()
    const decoded = JSON.parse(Buffer.from(identityToken.split('.')[1], 'base64').toString()) as {
      sub: string;
      email?: string;
    };
    const appleId = decoded.sub;
    const appleEmail = email ?? decoded.email ?? '';

    let user = await prisma.user.findUnique({
      where: { appleId },
      include: { business: { select: { id: true, name: true, logoUrl: true } } },
    });

    if (!user) {
      // First time Apple Sign In — create account
      const business = await prisma.business.create({
        data: { name: businessName ?? `${firstName ?? 'My'}'s Epoxy Business` },
      });

      user = await prisma.user.create({
        data: {
          appleId,
          email: appleEmail,
          firstName: firstName ?? 'User',
          lastName: lastName ?? '',
          businessId: business.id,
          plan: 'FREE_TRIAL',
          trialEndsAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
        },
        include: { business: { select: { id: true, name: true, logoUrl: true } } },
      });
    }

    const { accessToken, refreshToken } = generateTokens(user.id, user.businessId, user.role);

    res.json(successResponse({ user, business: user.business, accessToken, refreshToken }));
  } catch (error) {
    next(error);
  }
});

// ─── POST /auth/refresh ──────────────────────────────────────────────────
router.post('/refresh', validate(refreshSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { refreshToken } = req.body as { refreshToken: string };
    const refreshSecret = process.env.JWT_REFRESH_SECRET!;

    const payload = jwt.verify(refreshToken, refreshSecret) as {
      userId: string;
      businessId: string;
      role: string;
    };

    const tokens = generateTokens(payload.userId, payload.businessId, payload.role);
    res.json(successResponse(tokens));
  } catch {
    next(ApiError.unauthorized('Invalid or expired refresh token'));
  }
});

// ─── GET /auth/me ──────────────────────────────────────────────────────────
router.get('/me', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        avatarUrl: true,
        role: true,
        plan: true,
        trialEndsAt: true,
        business: {
          select: {
            id: true,
            name: true,
            logoUrl: true,
            phone: true,
            email: true,
            address: true,
            city: true,
            state: true,
            brandColor: true,
            accentColor: true,
          },
        },
      },
    });

    if (!user) throw ApiError.notFound('User');
    res.json(successResponse(user));
  } catch (error) {
    next(error);
  }
});

export default router;
