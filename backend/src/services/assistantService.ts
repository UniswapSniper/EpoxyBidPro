import OpenAI from 'openai';
import { logger } from '../utils/logger';

type AssistantMode = 'chat' | 'daily_briefing' | 'follow_up_draft' | 'invoice_reminder';
type AssistantTone = 'concise' | 'friendly' | 'direct';

type AssistantContext = {
  activeTab?: string;
  businessName?: string;
  metrics?: {
    leadCount?: number;
    overdueFollowUps?: number;
    draftBidCount?: number;
    scheduledJobCount?: number;
    overdueInvoiceCount?: number;
    openInvoiceBalance?: number;
  };
};

type AssistantReplyInput = {
  message: string;
  mode?: AssistantMode;
  tone?: AssistantTone;
  context?: AssistantContext;
  maxTokens?: number;
};

const SYSTEM_PROMPT = `You are EpoxyBidPro Assistant, an expert workflow copilot for epoxy flooring contractors.
Keep answers practical, concise, and action-oriented.
Prioritize safety, profitability, scheduling reliability, and customer communication quality.
When possible, suggest the next best action in the app.`;

function modeInstruction(mode?: AssistantMode): string {
  switch (mode) {
    case 'daily_briefing':
      return 'Return a concise daily execution briefing with top priorities, risks, and a one-line next action.';
    case 'follow_up_draft':
      return 'Write a professional follow-up draft that is specific, polite, and easy to send by text or email.';
    case 'invoice_reminder':
      return 'Write a firm but friendly invoice reminder that preserves client trust and asks for a specific payment action.';
    default:
      return 'Answer naturally as a workflow copilot and keep it practical.';
  }
}

function toneInstruction(tone?: AssistantTone): string {
  switch (tone) {
    case 'friendly':
      return 'Use a warm and supportive tone.';
    case 'direct':
      return 'Use a direct and no-fluff tone.';
    default:
      return 'Keep the response concise and professional.';
  }
}

function fallbackReply(message: string, mode?: AssistantMode): string {
  if (mode === 'daily_briefing') {
    return 'Daily briefing: 1) Clear overdue follow-ups first. 2) Advance draft bids to sent status. 3) Review overdue invoices and send reminders. Next action: Start in CRM and complete the top 3 overdue follow-ups.';
  }

  if (mode === 'follow_up_draft') {
    return 'Hi [Client Name], just checking in on your epoxy project estimate. I can answer any questions and adjust scope options to match your timeline and budget. Would you like me to reserve a site date this week?';
  }

  if (mode === 'invoice_reminder') {
    return 'Hi [Client Name], quick reminder that invoice [#] is currently due. You can use the payment link to complete it today. If you need a copy or have any questions, I can send that over right away.';
  }

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

export async function getAssistantReply(input: AssistantReplyInput): Promise<string> {
  const { message, mode, tone, context, maxTokens } = input;

  if (!process.env.XAI_API_KEY) {
    logger.warn('XAI_API_KEY not set — returning local assistant fallback response');
    return fallbackReply(message, mode);
  }

  const client = new OpenAI({
    apiKey: process.env.XAI_API_KEY,
    baseURL: process.env.XAI_BASE_URL ?? 'https://api.x.ai/v1',
  });

  const contextHint = [
    context?.activeTab ? `Active tab: ${context.activeTab}` : null,
    context?.businessName ? `Business: ${context.businessName}` : null,
    typeof context?.metrics?.leadCount === 'number' ? `Leads: ${context.metrics.leadCount}` : null,
    typeof context?.metrics?.overdueFollowUps === 'number'
      ? `Overdue follow-ups: ${context.metrics.overdueFollowUps}`
      : null,
    typeof context?.metrics?.draftBidCount === 'number' ? `Draft bids: ${context.metrics.draftBidCount}` : null,
    typeof context?.metrics?.scheduledJobCount === 'number'
      ? `Scheduled jobs: ${context.metrics.scheduledJobCount}`
      : null,
    typeof context?.metrics?.overdueInvoiceCount === 'number'
      ? `Overdue invoices: ${context.metrics.overdueInvoiceCount}`
      : null,
    typeof context?.metrics?.openInvoiceBalance === 'number'
      ? `Open invoice balance: $${context.metrics.openInvoiceBalance.toFixed(2)}`
      : null,
  ]
    .filter(Boolean)
    .join(' | ');

  const completion = await client.chat.completions.create({
    model: process.env.XAI_MODEL ?? 'grok-4.1-fast',
    temperature: 0.2,
    max_tokens: maxTokens ?? parseInt(process.env.XAI_MAX_TOKENS ?? '512', 10),
    messages: [
      {
        role: 'system',
        content: `${SYSTEM_PROMPT}\n${modeInstruction(mode)}\n${toneInstruction(tone)}`,
      },
      {
        role: 'user',
        content: contextHint.length > 0 ? `${contextHint}\n\nUser message: ${message}` : message,
      },
    ],
  });

  const reply = completion.choices[0]?.message?.content?.trim();
  return reply && reply.length > 0 ? reply : fallbackReply(message, mode);
}
