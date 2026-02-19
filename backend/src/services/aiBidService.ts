import OpenAI from 'openai';
import { Bid, Client, CoatingSystem, SurfaceCondition } from '@prisma/client';

type AiInput = {
  bid: Pick<Bid, 'id' | 'totalSqFt' | 'coatingSystem' | 'surfaceCondition' | 'totalPrice'>;
  client?: Pick<Client, 'type' | 'city' | 'state'> | null;
  marketContext?: string;
  historicalWinRate?: number;
};

export type AiSuggestionResult = {
  summary: string;
  riskFlags: string[];
  upsells: string[];
  marketContext: string;
};

const fallbackForCondition = (condition?: SurfaceCondition | null): string => {
  if (condition === 'POOR') return 'Substrate is POOR; add significant prep contingency and crack repair allowance.';
  if (condition === 'FAIR') return 'Surface is FAIR; include extra grinding and patching time to avoid callbacks.';
  return 'No major surface-risk indicators detected.';
};

const fallbackForSystem = (system?: CoatingSystem | null): string => {
  if (system === 'POLYASPARTIC') return 'Offer same-day return-to-service premium option with polyaspartic topcoat.';
  if (system === 'FULL_METALLIC') return 'Offer designer metallic sample board and premium clear topcoat upgrade.';
  return 'Offer anti-slip additive package and extended workmanship warranty.';
};

export async function getAiBidSuggestions(input: AiInput): Promise<AiSuggestionResult> {
  if (!process.env.OPENAI_API_KEY) {
    return {
      summary: 'AI fallback mode: generated rule-based guidance because OPENAI_API_KEY is not set.',
      riskFlags: [fallbackForCondition(input.bid.surfaceCondition)],
      upsells: [fallbackForSystem(input.bid.coatingSystem)],
      marketContext: input.marketContext ?? 'No explicit market context was provided.',
    };
  }

  const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const prompt = {
    sqft: input.bid.totalSqFt,
    coatingSystem: input.bid.coatingSystem,
    surfaceCondition: input.bid.surfaceCondition,
    currentPrice: input.bid.totalPrice,
    clientType: input.client?.type,
    location: [input.client?.city, input.client?.state].filter(Boolean).join(', '),
    marketContext: input.marketContext,
    historicalWinRate: input.historicalWinRate,
  };

  const response = await client.responses.create({
    model: process.env.OPENAI_BID_MODEL ?? 'gpt-4o-mini',
    input: [
      {
        role: 'system',
        content:
          'You are an epoxy flooring estimator assistant. Return compact JSON with summary, riskFlags (array), upsells (array), marketContext.'
      },
      {
        role: 'user',
        content: `Analyze this bid context and suggest actionable pricing guidance: ${JSON.stringify(prompt)}`
      }
    ],
    max_output_tokens: 350,
  });

  const outputText = response.output_text;
  try {
    const parsed = JSON.parse(outputText) as AiSuggestionResult;
    return {
      summary: parsed.summary,
      riskFlags: parsed.riskFlags ?? [],
      upsells: parsed.upsells ?? [],
      marketContext: parsed.marketContext ?? 'Market context not returned.',
    };
  } catch {
    return {
      summary: outputText || 'AI response received.',
      riskFlags: [fallbackForCondition(input.bid.surfaceCondition)],
      upsells: [fallbackForSystem(input.bid.coatingSystem)],
      marketContext: input.marketContext ?? 'Market context unavailable.',
    };
  }
}
