// ─── Strike API Client ──────────────────────────────────────────────────────
// Thin wrapper around the Strike REST API for Bitcoin/Lightning payment processing.
// Strike handles BTC↔USD conversion, exchange rate locking, and USD settlement.
// Docs: https://docs.strike.me/api/

import crypto from 'crypto';
import { logger } from './logger';

const STRIKE_API_BASE = process.env.STRIKE_API_BASE ?? 'https://api.strike.me/v1';

interface StrikeInvoiceResponse {
  invoiceId: string;
  amount: { amount: string; currency: string };
  state: 'UNPAID' | 'PENDING' | 'PAID' | 'CANCELLED';
  created: string;
  expirationInSec: number;
  description: string;
}

interface StrikeQuoteResponse {
  quoteId: string;
  description: string;
  lnInvoice: string;          // Lightning invoice (BOLT11)
  onchainAddress: string;     // On-chain fallback address
  expiration: string;         // ISO timestamp
  expirationInSec: number;
  targetAmount: { amount: string; currency: string };
  sourceAmount: { amount: string; currency: string };  // BTC amount
  conversionRate: { amount: string; sourceCurrency: string; targetCurrency: string };
}

export interface BitcoinInvoiceResult {
  strikeInvoiceId: string;
  paymentUri: string;
  lnInvoice: string;
  onchainAddress: string;
  amountUsd: number;
  amountBtcSats: number;
  exchangeRate: number;
  expiresAt: string;
}

export interface BitcoinInvoiceStatus {
  strikeInvoiceId: string;
  state: 'UNPAID' | 'PENDING' | 'PAID' | 'CANCELLED';
  amountUsd: number;
  amountBtcSats: number;
  exchangeRate: number;
}

async function strikeRequest<T>(
  path: string,
  apiKey: string,
  options: { method?: string; body?: unknown } = {},
): Promise<T> {
  const { method = 'GET', body } = options;

  const res = await fetch(`${STRIKE_API_BASE}${path}`, {
    method,
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    const errorBody = await res.text();
    logger.error(`Strike API error: ${res.status} ${errorBody}`);
    throw new Error(`Strike API error: ${res.status} — ${errorBody}`);
  }

  return res.json() as Promise<T>;
}

/**
 * Creates a Strike invoice for a USD amount and immediately generates a quote
 * (which provides the Lightning invoice and on-chain address).
 */
export async function createBitcoinInvoice(
  amountUsd: number,
  description: string,
  apiKey: string,
): Promise<BitcoinInvoiceResult> {
  // Step 1: Create an invoice in USD
  const invoice = await strikeRequest<StrikeInvoiceResponse>('/invoices', apiKey, {
    method: 'POST',
    body: {
      correlationId: crypto.randomUUID(),
      description,
      amount: { currency: 'USD', amount: amountUsd.toFixed(2) },
    },
  });

  // Step 2: Generate a quote (locks exchange rate, returns LN invoice + on-chain address)
  const quote = await strikeRequest<StrikeQuoteResponse>(
    `/invoices/${invoice.invoiceId}/quote`,
    apiKey,
    { method: 'POST' },
  );

  const btcAmount = parseFloat(quote.sourceAmount.amount);
  const btcSats = Math.round(btcAmount * 1e8);
  const exchangeRate = parseFloat(quote.conversionRate.amount);

  // Build a BIP21 payment URI with Lightning fallback
  const paymentUri = `bitcoin:${quote.onchainAddress}?amount=${btcAmount}&lightning=${quote.lnInvoice}`;

  return {
    strikeInvoiceId: invoice.invoiceId,
    paymentUri,
    lnInvoice: quote.lnInvoice,
    onchainAddress: quote.onchainAddress,
    amountUsd,
    amountBtcSats: btcSats,
    exchangeRate,
    expiresAt: quote.expiration,
  };
}

/**
 * Checks the current status of a Strike invoice.
 */
export async function getBitcoinInvoiceStatus(
  strikeInvoiceId: string,
  apiKey: string,
): Promise<BitcoinInvoiceStatus> {
  const invoice = await strikeRequest<StrikeInvoiceResponse>(
    `/invoices/${strikeInvoiceId}`,
    apiKey,
  );

  const amountUsd = parseFloat(invoice.amount.amount);

  // If paid, re-fetch quote details (or use cached values)
  // For status checks we return what we know from the invoice
  return {
    strikeInvoiceId: invoice.invoiceId,
    state: invoice.state,
    amountUsd,
    amountBtcSats: 0, // populated from stored Payment record
    exchangeRate: 0,   // populated from stored Payment record
  };
}

/**
 * Verifies a Strike webhook signature.
 * Strike signs webhooks with HMAC-SHA256 using your webhook secret.
 */
export function verifyStrikeWebhook(
  rawBody: string | Buffer,
  signatureHeader: string,
  webhookSecret: string,
): boolean {
  const expected = crypto
    .createHmac('sha256', webhookSecret)
    .update(rawBody)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(expected, 'hex'),
    Buffer.from(signatureHeader, 'hex'),
  );
}
