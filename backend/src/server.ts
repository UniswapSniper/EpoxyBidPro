import 'dotenv/config';
import { app } from './app';
import { logger } from './utils/logger';
import { prisma } from './utils/prisma';

const PORT = parseInt(process.env.API_PORT ?? '3000', 10);

async function startServer(): Promise<void> {
  try {
    // Verify database connection
    await prisma.$connect();
    logger.info('✅ Database connection established');

    const server = app.listen(PORT, () => {
      logger.info(`🚀 EpoxyBidPro API running on port ${PORT} [${process.env.NODE_ENV}]`);
    });

    // ─── Graceful Shutdown ────────────────────────────────────────────
    const shutdown = async (signal: string): Promise<void> => {
      logger.info(`📴 ${signal} received — shutting down gracefully...`);
      server.close(async () => {
        await prisma.$disconnect();
        logger.info('💾 Database disconnected');
        process.exit(0);
      });

      // Force exit after 10s if not closed
      setTimeout(() => {
        logger.error('⚠️  Forced shutdown after timeout');
        process.exit(1);
      }, 10000);
    };

    process.on('SIGTERM', () => void shutdown('SIGTERM'));
    process.on('SIGINT', () => void shutdown('SIGINT'));
  } catch (error) {
    logger.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

void startServer();
