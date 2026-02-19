/**
 * EmailService
 * ─────────────────────────────────────────────────────────────────────────────
 * Thin wrapper around SendGrid for transactional email delivery.
 * Covers bid/proposal delivery, view-receipts, and follow-up sequences.
 *
 * Phase 5 — Bid & Proposal Generation
 */

import sgMail from '@sendgrid/mail';
import { logger } from '../utils/logger';

sgMail.setApiKey(process.env.SENDGRID_API_KEY ?? '');

const FROM_EMAIL = process.env.SENDGRID_FROM_EMAIL ?? 'noreply@epoxybidpro.com';
const FROM_NAME  = process.env.SENDGRID_FROM_NAME  ?? 'EpoxyBidPro';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SendProposalOptions {
  toEmail: string;
  toName: string;
  fromBusinessName: string;
  bidNumber: string;
  pdfUrl: string;
  customMessage?: string;
  /** Public URL the client can use to view/sign the bid in a browser */
  viewUrl?: string;
}

export interface SendBidFollowUpOptions {
  toEmail: string;
  toName: string;
  fromBusinessName: string;
  bidNumber: string;
  dayNumber: 1 | 3 | 7;
  viewUrl?: string;
}

export interface SendSignedConfirmationOptions {
  toEmail: string;
  toName: string;
  fromBusinessName: string;
  bidNumber: string;
  totalPrice: number;
}

// ─── Send Proposal ────────────────────────────────────────────────────────────

/**
 * Sends the proposal PDF to the client via email with a personalised message.
 */
export async function sendProposalEmail(opts: SendProposalOptions): Promise<void> {
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto;">
      <div style="background: #1E3A5F; padding: 24px; border-radius: 8px 8px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 22px;">${opts.fromBusinessName}</h1>
        <p style="color: rgba(255,255,255,0.8); margin: 4px 0 0;">Professional Epoxy Flooring Proposal</p>
      </div>
      <div style="background: #fafafa; padding: 32px; border: 1px solid #e5e7eb; border-top: none;">
        <p>Hi ${opts.toName},</p>
        ${opts.customMessage
          ? `<p>${opts.customMessage}</p>`
          : `<p>Please find attached your personalised epoxy flooring proposal <strong>${opts.bidNumber}</strong>. We look forward to working with you!</p>`
        }
        <div style="margin: 28px 0; text-align: center;">
          <a href="${opts.pdfUrl}" style="
            background: #1E3A5F; color: white; padding: 14px 32px;
            border-radius: 6px; text-decoration: none; font-weight: bold; font-size: 16px;
          ">📄 Download Proposal</a>
        </div>
        ${opts.viewUrl ? `
        <p style="text-align: center; font-size: 13px; color: #666;">
          Or <a href="${opts.viewUrl}" style="color: #3B82F6;">view &amp; sign online</a>
        </p>` : ''}
        <p style="color: #555;">If you have any questions, please reply to this email or call us directly.</p>
        <p>Best regards,<br><strong>${opts.fromBusinessName}</strong></p>
      </div>
      <div style="background: #f1f5f9; padding: 16px; text-align: center; font-size: 11px; color: #888; border-radius: 0 0 8px 8px;">
        Sent via EpoxyBidPro · <a href="https://epoxybidpro.com" style="color: #888;">epoxybidpro.com</a>
      </div>
    </div>
  `;

  await deliver({
    to: { email: opts.toEmail, name: opts.toName },
    subject: `Your Epoxy Flooring Proposal — ${opts.bidNumber}`,
    html,
    attachments: [
      {
        content: '',   // not attaching the PDF inline — client downloads via link
        filename: `${opts.bidNumber}-proposal.pdf`,
        type: 'application/pdf',
        disposition: 'none',
      },
    ],
  });

  logger.info(`Proposal email sent: ${opts.bidNumber} → ${opts.toEmail}`);
}

// ─── Follow-up Sequence ───────────────────────────────────────────────────────

const FOLLOW_UP_MESSAGES: Record<1 | 3 | 7, string> = {
  1: "Just following up to make sure you received your proposal. We'd love to answer any questions!",
  3: "We wanted to check in on your flooring project. Your proposal is still available — don't hesitate to reach out.",
  7: "Your proposal is valid for a limited time. We have crew availability that works great for your timeline. Let's get started!",
};

export async function sendFollowUpEmail(opts: SendBidFollowUpOptions): Promise<void> {
  const message = FOLLOW_UP_MESSAGES[opts.dayNumber];

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto;">
      <div style="background: #1E3A5F; padding: 20px; border-radius: 8px 8px 0 0;">
        <h2 style="color: white; margin: 0;">${opts.fromBusinessName}</h2>
      </div>
      <div style="background: #fafafa; padding: 28px; border: 1px solid #e5e7eb; border-top: none;">
        <p>Hi ${opts.toName},</p>
        <p>${message}</p>
        ${opts.viewUrl ? `
        <div style="margin: 24px 0; text-align: center;">
          <a href="${opts.viewUrl}" style="
            background: #3B82F6; color: white; padding: 12px 28px;
            border-radius: 6px; text-decoration: none; font-weight: bold;
          ">View Proposal ${opts.bidNumber}</a>
        </div>` : ''}
        <p>Best regards,<br><strong>${opts.fromBusinessName}</strong></p>
      </div>
    </div>
  `;

  await deliver({
    to: { email: opts.toEmail, name: opts.toName },
    subject: `Following up on your flooring proposal — ${opts.bidNumber}`,
    html,
  });

  logger.info(`Follow-up day-${opts.dayNumber} email sent: ${opts.bidNumber} → ${opts.toEmail}`);
}

// ─── Signed Confirmation ──────────────────────────────────────────────────────

export async function sendSignedConfirmationEmail(opts: SendSignedConfirmationOptions): Promise<void> {
  const formattedTotal = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(opts.totalPrice);

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto;">
      <div style="background: #16a34a; padding: 24px; border-radius: 8px 8px 0 0;">
        <h1 style="color: white; margin: 0;">✅ Proposal Accepted!</h1>
      </div>
      <div style="background: #fafafa; padding: 32px; border: 1px solid #e5e7eb; border-top: none;">
        <p>Hi ${opts.toName},</p>
        <p>Thank you for signing your proposal <strong>${opts.bidNumber}</strong>!</p>
        <p><strong>Project Total: ${formattedTotal}</strong></p>
        <p>Our team will reach out soon to schedule your project start date. We're excited to transform your space!</p>
        <p>Best regards,<br><strong>${opts.fromBusinessName}</strong></p>
      </div>
    </div>
  `;

  await deliver({
    to: { email: opts.toEmail, name: opts.toName },
    subject: `Proposal Confirmed — ${opts.bidNumber} — Welcome aboard!`,
    html,
  });

  logger.info(`Signed confirmation email sent: ${opts.bidNumber} → ${opts.toEmail}`);
}

// ─── Internal delivery helper ─────────────────────────────────────────────────

interface MailPayload {
  to: { email: string; name: string };
  subject: string;
  html: string;
  attachments?: Array<{
    content: string;
    filename: string;
    type: string;
    disposition: string;
  }>;
}

async function deliver(payload: MailPayload): Promise<void> {
  if (process.env.NODE_ENV === 'test') return; // skip in unit tests

  if (!process.env.SENDGRID_API_KEY) {
    logger.warn('SENDGRID_API_KEY not set — email delivery skipped (dev mode)');
    return;
  }

  const msg = {
    to: payload.to,
    from: { email: FROM_EMAIL, name: FROM_NAME },
    subject: payload.subject,
    html: payload.html,
    ...(payload.attachments && { attachments: payload.attachments }),
  };

  const [response] = await sgMail.send(msg as Parameters<typeof sgMail.send>[0]);
  logger.info(`SendGrid delivery status: ${response.statusCode} for "${payload.subject}"`);
}
