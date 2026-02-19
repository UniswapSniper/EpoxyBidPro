import { Router } from 'express';
import authRoutes from './auth';
import clientRoutes from './clients';
import leadRoutes from './leads';
import measurementRoutes from './measurements';
import bidRoutes from './bids';
import jobRoutes from './jobs';
import invoiceRoutes from './invoices';
import paymentRoutes from './payments';
import photoRoutes from './photos';
import analyticsRoutes from './analytics';
import crewRoutes from './crew';
import materialRoutes from './materials';
import notificationRoutes from './notifications';
import crmRoutes from './crm';
import templateRoutes from './templates';
import documentRoutes from './documents';

export const router = Router();

// ─── Public Routes ──────────────────────────────────────────────────────────
router.use('/auth', authRoutes);

// ─── Protected Routes (JWT required — applied inside each route file) ────────
// NOTE: Bids are the single unified concept for pricing + proposals.
// There is no separate /quotes endpoint in EpoxyBidPro.
router.use('/clients', clientRoutes);
router.use('/leads', leadRoutes);
router.use('/measurements', measurementRoutes);
router.use('/bids', bidRoutes);
router.use('/jobs', jobRoutes);
router.use('/invoices', invoiceRoutes);
router.use('/payments', paymentRoutes);
router.use('/photos', photoRoutes);
router.use('/analytics', analyticsRoutes);
router.use('/crew', crewRoutes);
router.use('/materials', materialRoutes);
router.use('/notifications', notificationRoutes);
router.use('/crm', crmRoutes);
router.use('/templates', templateRoutes);
router.use('/documents', documentRoutes);
