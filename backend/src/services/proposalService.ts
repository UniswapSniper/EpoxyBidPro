/**
 * ProposalService
 * ─────────────────────────────────────────────────────────────────────────────
 * Generates branded PDF proposals from Bid data using PDFKit.
 * The finished PDF is uploaded to S3 and the URL is returned.
 *
 * Phase 5 — Bid & Proposal Generation
 */

import PDFDocument from 'pdfkit';
import AWS from 'aws-sdk';
import { logger } from '../utils/logger';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface ProposalBid {
  id: string;
  bidNumber: string;
  version: number;
  title: string;
  executiveSummary?: string | null;
  scopeNotes?: string | null;
  validUntil?: Date | null;
  totalSqFt: number;
  coatingSystem: string;
  materialCost: number;
  laborCost: number;
  overheadCost: number;
  mobilizationFee: number;
  subtotal: number;
  markup: number;
  taxAmount: number;
  totalPrice: number;
  estimatedDays: number;
  tier: string;
  aiRiskFlags: string[];
  aiUpsells: string[];
  lineItems: Array<{
    category: string;
    description: string;
    quantity: number;
    unit: string;
    unitCost: number;
    totalCost: number;
    totalPrice: number;
    isVisible: boolean;
  }>;
  client?: {
    firstName: string;
    lastName: string;
    company?: string | null;
    email?: string | null;
    phone?: string | null;
    address?: string | null;
    city?: string | null;
    state?: string | null;
    zip?: string | null;
  } | null;
  measurement?: {
    name: string;
    totalSqFt: number;
    areas: Array<{ label: string; sqFt: number }>;
  } | null;
}

export interface BusinessBranding {
  name: string;
  phone?: string | null;
  email?: string | null;
  website?: string | null;
  address?: string | null;
  city?: string | null;
  state?: string | null;
  zip?: string | null;
  logoUrl?: string | null;
  brandColor: string;   // hex, e.g. "#1E3A5F"
  accentColor: string;
  licenseNumber?: string | null;
  warranty?: string | null;
  terms?: string | null;
  about?: string | null;
  quoteFooter?: string | null;
}

// ─── S3 Setup ─────────────────────────────────────────────────────────────────

const s3 = new AWS.S3({
  region: process.env.AWS_REGION ?? 'us-east-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
});

const S3_BUCKET = process.env.AWS_S3_BUCKET ?? 'epoxybidpro-files';

// ─── Colour helpers ───────────────────────────────────────────────────────────

function hexToRgb(hex: string): [number, number, number] {
  const clean = hex.replace('#', '');
  const r = parseInt(clean.substring(0, 2), 16);
  const g = parseInt(clean.substring(2, 4), 16);
  const b = parseInt(clean.substring(4, 6), 16);
  return [r, g, b];
}

function formatCurrency(val: number): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val);
}

function formatDate(d: Date | null | undefined): string {
  if (!d) return '—';
  return new Intl.DateTimeFormat('en-US', { dateStyle: 'long' }).format(new Date(d));
}

// ─── PDF Generator ────────────────────────────────────────────────────────────

/**
 * Build the proposal PDF buffer.
 * Returns a Buffer containing the complete PDF file.
 */
export async function buildProposalPdf(
  bid: ProposalBid,
  branding: BusinessBranding,
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 50, size: 'LETTER' });
    const chunks: Buffer[] = [];

    doc.on('data', (chunk: Buffer) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const primary = hexToRgb(branding.brandColor);
    const accent  = hexToRgb(branding.accentColor);

    // ── Cover Banner ──────────────────────────────────────────────────────────
    doc
      .rect(0, 0, doc.page.width, 120)
      .fill(`rgb(${primary[0]},${primary[1]},${primary[2]})`);

    doc
      .fillColor('white')
      .font('Helvetica-Bold')
      .fontSize(24)
      .text(branding.name, 50, 30, { align: 'left' });

    doc
      .font('Helvetica')
      .fontSize(10)
      .text(
        [branding.phone, branding.email, branding.website].filter(Boolean).join('  |  '),
        50,
        62,
        { align: 'left' },
      );

    if (branding.licenseNumber) {
      doc.text(`License #${branding.licenseNumber}`, 50, 80);
    }

    // Bid number & date — top right
    doc
      .font('Helvetica-Bold')
      .fontSize(14)
      .text(`Proposal ${bid.bidNumber}`, 0, 30, { align: 'right', width: doc.page.width - 50 })
      .font('Helvetica')
      .fontSize(10)
      .text(`Date: ${formatDate(new Date())}`, 0, 52, { align: 'right', width: doc.page.width - 50 })
      .text(`Valid Until: ${formatDate(bid.validUntil)}`, 0, 68, { align: 'right', width: doc.page.width - 50 });

    doc.moveDown(4);

    // ── Client & Property ─────────────────────────────────────────────────────
    const client = bid.client;
    doc
      .fillColor(`rgb(${primary[0]},${primary[1]},${primary[2]})`)
      .font('Helvetica-Bold')
      .fontSize(14)
      .text('Prepared For', 50, 140);

    doc.moveTo(50, 158).lineTo(doc.page.width - 50, 158)
      .stroke(`rgb(${accent[0]},${accent[1]},${accent[2]})`);

    doc.fillColor('#222222').font('Helvetica').fontSize(11);
    if (client) {
      const clientName = [client.firstName, client.lastName].join(' ').trim();
      const company = client.company ?? '';
      doc.text(company || clientName, 50, 168);
      if (company) doc.text(clientName, 50);
      const addr = [client.address, client.city, client.state, client.zip]
        .filter(Boolean).join(', ');
      if (addr) doc.text(addr);
      if (client.phone) doc.text(client.phone);
      if (client.email) doc.text(client.email);
    }

    doc.moveDown(1.5);

    // ── Title & Executive Summary ─────────────────────────────────────────────
    const yAfterClient = doc.y;

    doc
      .fillColor(`rgb(${primary[0]},${primary[1]},${primary[2]})`)
      .font('Helvetica-Bold')
      .fontSize(18)
      .text(bid.title, 50, yAfterClient + 10);

    if (bid.executiveSummary) {
      doc.moveDown(0.5)
        .fillColor('#444444')
        .font('Helvetica')
        .fontSize(11)
        .text(bid.executiveSummary, { align: 'justify' });
    }

    doc.moveDown(1.5);

    // ── Scope of Work ─────────────────────────────────────────────────────────
    sectionHeader(doc, 'Scope of Work', primary);

    // Area breakdown
    if (bid.measurement?.areas?.length) {
      doc.fillColor('#333333').font('Helvetica-Bold').fontSize(11).text('Measurement Breakdown:');
      bid.measurement.areas.forEach(area => {
        doc.font('Helvetica').fontSize(10)
          .text(`  • ${area.label}: ${area.sqFt.toLocaleString()} sq ft`);
      });
      doc.font('Helvetica-Bold').fontSize(10)
        .text(`  Total: ${bid.totalSqFt.toLocaleString()} sq ft`);
      doc.moveDown(0.5);
    } else {
      doc.font('Helvetica').fontSize(10)
        .fillColor('#333333')
        .text(`Total Floor Area: ${bid.totalSqFt.toLocaleString()} sq ft`);
      doc.moveDown(0.5);
    }

    // Coating system & timeline
    doc.font('Helvetica').fontSize(10).fillColor('#333333')
      .text(`Coating System: ${formatCoatingSystem(bid.coatingSystem)}`)
      .text(`Tier Selection: ${bid.tier}`)
      .text(`Estimated Completion: ${bid.estimatedDays} day${bid.estimatedDays !== 1 ? 's' : ''}`)
      .moveDown(0.5);

    if (bid.scopeNotes) {
      doc.text(bid.scopeNotes, { align: 'justify' });
    }

    doc.moveDown(1);

    // ── Line Items (Investment Breakdown) ─────────────────────────────────────
    const visibleItems = bid.lineItems.filter(li => li.isVisible);
    if (visibleItems.length) {
      sectionHeader(doc, 'Investment Breakdown', primary);
      lineItemsTable(doc, visibleItems, accent);
      doc.moveDown(0.5);
    }

    // ── Pricing Summary ───────────────────────────────────────────────────────
    sectionHeader(doc, 'Investment Summary', primary);
    const summaryRows: [string, string][] = [
      ['Materials', formatCurrency(bid.materialCost)],
      ['Labor', formatCurrency(bid.laborCost)],
      ['Overhead & Profit', formatCurrency(bid.overheadCost + bid.markup)],
    ];
    if (bid.mobilizationFee > 0) summaryRows.push(['Mobilization', formatCurrency(bid.mobilizationFee)]);
    if (bid.taxAmount > 0) summaryRows.push(['Tax', formatCurrency(bid.taxAmount)]);

    summaryRows.forEach(([label, val]) => {
      doc.font('Helvetica').fontSize(11).fillColor('#333333')
        .text(label, 50, doc.y, { continued: true })
        .text(val, { align: 'right' });
    });

    // Total price row
    doc.moveDown(0.3)
      .rect(50, doc.y, doc.page.width - 100, 28)
      .fill(`rgb(${primary[0]},${primary[1]},${primary[2]})`);

    const totalY = doc.y + 7;
    doc.fillColor('white').font('Helvetica-Bold').fontSize(13)
      .text('TOTAL INVESTMENT', 60, totalY, { continued: true })
      .text(formatCurrency(bid.totalPrice), { align: 'right' });

    doc.moveDown(2);

    // ── Warranty & Terms ──────────────────────────────────────────────────────
    if (branding.warranty) {
      sectionHeader(doc, 'Warranty', primary);
      doc.font('Helvetica').fontSize(9).fillColor('#555555').text(branding.warranty);
      doc.moveDown(1);
    }

    if (branding.terms) {
      sectionHeader(doc, 'Terms & Conditions', primary);
      doc.font('Helvetica').fontSize(9).fillColor('#555555').text(branding.terms);
      doc.moveDown(1);
    }

    // ── About ─────────────────────────────────────────────────────────────────
    if (branding.about) {
      sectionHeader(doc, 'About Us', primary);
      doc.font('Helvetica').fontSize(9).fillColor('#555555').text(branding.about);
      doc.moveDown(1);
    }

    // ── Signature Block ───────────────────────────────────────────────────────
    sectionHeader(doc, 'Authorization & Acceptance', primary);
    const sigY = doc.y + 10;

    doc.moveTo(50, sigY + 30).lineTo(250, sigY + 30).stroke('#999999');
    doc.font('Helvetica').fontSize(8).fillColor('#666666')
      .text('Client Signature', 50, sigY + 34);

    doc.moveTo(300, sigY + 30).lineTo(500, sigY + 30).stroke('#999999');
    doc.text('Printed Name', 300, sigY + 34);

    doc.moveTo(50, sigY + 60).lineTo(250, sigY + 60).stroke('#999999');
    doc.text('Date', 50, sigY + 64);

    // ── Footer ────────────────────────────────────────────────────────────────
    const footerY = doc.page.height - 55;
    doc.rect(0, footerY, doc.page.width, 55)
      .fill(`rgb(${primary[0]},${primary[1]},${primary[2]})`);

    doc.fillColor('white').font('Helvetica').fontSize(8)
      .text(
        branding.quoteFooter ?? `${branding.name} — Professional Epoxy Flooring`,
        50,
        footerY + 10,
        { align: 'center', width: doc.page.width - 100 },
      )
      .text(
        [branding.address, branding.city, branding.state].filter(Boolean).join(', '),
        { align: 'center', width: doc.page.width - 100 },
      );

    doc.end();
  });
}

// ─── S3 Upload ────────────────────────────────────────────────────────────────

/**
 * Upload a PDF buffer to S3 and return the public URL.
 */
export async function uploadProposalToS3(
  pdfBuffer: Buffer,
  bidId: string,
  bidNumber: string,
): Promise<string> {
  const key = `proposals/${bidId}/${bidNumber}-v${Date.now()}.pdf`;

  await s3
    .putObject({
      Bucket: S3_BUCKET,
      Key: key,
      Body: pdfBuffer,
      ContentType: 'application/pdf',
      ContentDisposition: `inline; filename="${bidNumber}-proposal.pdf"`,
    })
    .promise();

  const region = process.env.AWS_REGION ?? 'us-east-1';
  const url = `https://${S3_BUCKET}.s3.${region}.amazonaws.com/${key}`;
  logger.info(`Proposal PDF uploaded: ${url}`);
  return url;
}

/**
 * Generates a proposal PDF, uploads to S3, and returns the URL.
 * In non-production environments without S3 credentials configured, returns a
 * placeholder URL so local development doesn't fail.
 */
export async function generateAndUploadProposal(
  bid: ProposalBid,
  branding: BusinessBranding,
): Promise<string> {
  try {
    const buffer = await buildProposalPdf(bid, branding);
    const url = await uploadProposalToS3(buffer, bid.id, bid.bidNumber);
    return url;
  } catch (err) {
    if (process.env.NODE_ENV !== 'production') {
      logger.warn('S3 upload skipped in dev — returning placeholder PDF URL');
      return `https://dev-placeholder.local/proposals/${bid.bidNumber}.pdf`;
    }
    throw err;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function sectionHeader(doc: PDFKit.PDFDocument, title: string, color: [number, number, number]): void {
  doc
    .fillColor(`rgb(${color[0]},${color[1]},${color[2]})`)
    .font('Helvetica-Bold')
    .fontSize(13)
    .text(title);
  doc
    .moveTo(50, doc.y)
    .lineTo(doc.page.width - 50, doc.y)
    .stroke(`rgb(${color[0]},${color[1]},${color[2]})`);
  doc.moveDown(0.5);
}

function lineItemsTable(
  doc: PDFKit.PDFDocument,
  items: ProposalBid['lineItems'],
  accent: [number, number, number],
): void {
  const colX = { desc: 50, qty: 330, unit: 380, price: 430, total: 490 };
  const headerY = doc.y;

  doc.rect(50, headerY, doc.page.width - 100, 18)
    .fill(`rgb(${accent[0]},${accent[1]},${accent[2]})`);

  doc.fillColor('white').font('Helvetica-Bold').fontSize(9)
    .text('Description', colX.desc, headerY + 4)
    .text('Qty', colX.qty, headerY + 4)
    .text('Unit', colX.unit, headerY + 4)
    .text('Unit $', colX.price, headerY + 4)
    .text('Total', colX.total, headerY + 4);

  doc.moveDown(0.1);
  let rowY = doc.y + 4;
  let isEven = false;

  items.forEach(item => {
    if (isEven) {
      doc.rect(50, rowY - 2, doc.page.width - 100, 16).fill('#f5f5f5');
    }
    doc.fillColor('#333333').font('Helvetica').fontSize(9)
      .text(item.description, colX.desc, rowY, { width: 270 })
      .text(item.quantity.toString(), colX.qty, rowY)
      .text(item.unit || 'ea', colX.unit, rowY)
      .text(formatCurrency(item.unitCost), colX.price, rowY)
      .text(formatCurrency(item.totalPrice), colX.total, rowY);
    rowY += 18;
    isEven = !isEven;
  });

  doc.y = rowY + 4;
}

function formatCoatingSystem(system: string): string {
  return system
    .toLowerCase()
    .replace(/_/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}
