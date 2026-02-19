import { PrismaClient } from '@prisma/client';
import { logger } from './logger';

// Prevent multiple Prisma Client instances in development (hot reload)
const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma: PrismaClient =
  globalForPrisma.prisma ??
  new PrismaClient({
    log:
      process.env.NODE_ENV === 'development'
        ? [
            { emit: 'event', level: 'query' },
            { emit: 'event', level: 'warn' },
            { emit: 'event', level: 'error' },
          ]
        : [
            { emit: 'event', level: 'warn' },
            { emit: 'event', level: 'error' },
          ],
  });

if (process.env.NODE_ENV === 'development') {
  globalForPrisma.prisma = prisma;

  // Log query details in development
  (prisma as PrismaClient).$on('query' as never, (e: { query: string; duration: number }) => {
    logger.debug(`Query (${e.duration}ms): ${e.query}`);
  });
}

(prisma as PrismaClient).$on('warn' as never, (e: { message: string }) => {
  logger.warn('Prisma warning:', e.message);
});

(prisma as PrismaClient).$on('error' as never, (e: { message: string }) => {
  logger.error('Prisma error:', e.message);
});
