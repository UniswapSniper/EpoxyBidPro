import OpenAI from 'openai';
import { logger } from '../utils/logger';

type AssistantContext = {
  activeTab?: string;
  businessName?: string;
};

const SYSTEM_PROMPT = `You are EpoxyBidPro Assistant, an expert workflow copilot for epoxy flooring contractors.
Keep answers practical, concise, and action-oriented.
Prioritize safety, profitability, scheduling reliability, and customer communication quality.
When possible, suggest the next best action in the app.`;

function fallbackReply(message: string): string {
  const text = message.toLowerCase();

  if (text.includes('lead') || text.includes('follow')) {
    return 'Start in CRM and clear overdue follow-ups first, then prioritize recent SITE_VISIT leads to improve close rate.';
  }

  if (text.includes('bid') || text.includes('quote') || text.includes('price')) {
    return 'Open Bids, run Scan Space, then Build From Scan so scope and pricing are prefilled before you finalize the proposal.';
  }

  if (text.includes('invoice') || text.includes('payment') || text.includes('collect')) {
    return 'Open Invoicing, filter Overdue first, and send reminders before creating new invoices to improve collection velocity.';
  }

  if (text.includes('job') || text.includes('crew') || text.includes('schedule')) {
    return 'Open Jobs, create from signed bids, then use the at-risk view to catch schedule and margin issues early.';
  }

  return 'I can help with CRM follow-ups, bids, jobs, invoicing, and daily prioritization. Ask me your next decision.';
}

export async function getAssistantReply(
  message: string,
  context?: AssistantContext,
  maxTokens?: number
): Promise<string> {
  if (!process.env.XAI_API_KEY) {
    logger.warn('XAI_API_KEY not set — returning local assistant fallback response');
    return fallbackReply(message);
  }

  const client = new OpenAI({
    apiKey: process.env.XAI_API_KEY,
    baseURL: process.env.XAI_BASE_URL ?? 'https://api.x.ai/v1',
  });

  const contextHint = [
    context?.activeTab ? `Active tab: ${context.activeTab}` : null,
    context?.businessName ? `Business: ${context.businessName}` : null,
  ]
    .filter(Boolean)
    .join(' | ');

  const completion = await client.chat.completions.create({
    model: process.env.XAI_MODEL ?? 'grok-4.1-fast',
    temperature: 0.2,
    max_tokens: maxTokens ?? parseInt(process.env.XAI_MAX_TOKENS ?? '512', 10),
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      {
        role: 'user',
        content: contextHint.length > 0 ? `${contextHint}\n\nUser message: ${message}` : message,
      },
    ],
  });

  const reply = completion.choices[0]?.message?.content?.trim();
  return reply && reply.length > 0 ? reply : fallbackReply(message);
}
