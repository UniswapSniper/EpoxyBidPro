import { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { ZodError } from 'zod';
import { ApiError } from '../utils/apiError';
import { logger } from '../utils/logger';

/**
 * Global 404 handler — catches requests to undefined routes.
 */
export const notFoundHandler = (req: Request, _res: Response, next: NextFunction): void => {
  next(ApiError.notFound(`Route ${req.method} ${req.path}`));
};

/**
 * Global error handler — must be the last middleware registered.
 */
export const errorHandler = (
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void => {
  const requestId = req.headers['x-request-id'] as string;

  // ─── Operational API Errors ─────────────────────────────────
  if (err instanceof ApiError) {
    if (err.statusCode >= 500) {
      logger.error({ requestId, message: err.message, stack: err.stack });
    }
    res.status(err.statusCode).json({
      success: false,
      error: err.message,
      ...(err.details && { details: err.details }),
      requestId,
    });
    return;
  }

  // ─── Zod Validation Errors ──────────────────────────────────
  if (err instanceof ZodError) {
    res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: err.errors.map((e) => ({ path: e.path.join('.'), message: e.message })),
      requestId,
    });
    return;
  }

  // ─── Prisma Errors ──────────────────────────────────────────
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    switch (err.code) {
      case 'P2002':
        res.status(409).json({
          success: false,
          error: 'A record with this value already exists',
          requestId,
        });
        return;
      case 'P2025':
        res.status(404).json({
          success: false,
          error: 'Record not found',
          requestId,
        });
        return;
      default:
        logger.error({ requestId, prismaCode: err.code, message: err.message });
        res.status(500).json({
          success: false,
          error: 'Database error',
          requestId,
        });
        return;
    }
  }

  // ─── Unhandled Errors ───────────────────────────────────────
  logger.error({ requestId, message: err.message, stack: err.stack });
  res.status(500).json({
    success: false,
    error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
    requestId,
  });
};
