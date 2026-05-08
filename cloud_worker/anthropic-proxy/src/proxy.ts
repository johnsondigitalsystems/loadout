// =============================================================================
// FILE: cloud_worker/anthropic-proxy/src/proxy.ts
//
// Forward a Smart Import request to Anthropic's Messages API and turn
// the assistant text into the structured response shape the LoadOut
// client expects:
//
//   { improved_draft: { ... }, fields_changed: ["..."],
//     quota: { used_this_month, monthly_cap, resets_at } }
//
// We deliberately do NOT log request bodies. The only telemetry the
// Worker emits is the structured log line `console.log(...)` builds:
// timestamp, uid, status code, latency, token counts. The privacy
// posture (CLAUDE.md §13 / §20) says LoadOut never sees the user's
// reloading data, and request bodies — even OCR text — would risk
// breaking that promise if Cloudflare ever turned on body logging.
// =============================================================================

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const ANTHROPIC_VERSION = '2023-06-01';

const SYSTEM_PROMPT = `You translate handwritten reloading-notebook OCR into structured fields.

Output ONLY a single JSON object matching the shape provided. Do not add
explanations, refusals, or any other content. If you cannot improve a
field, omit it from the output. Never invent values not supported by the
OCR. You are NOT giving reloading advice — you are extracting what the
user already wrote.`;

export interface SmartImportRequest {
  ocr_text: string;
  initial_draft: Record<string, unknown>;
  catalog_hints?: Record<string, unknown>;
  model?: string;
}

export interface ImprovedDraft {
  recipeName?: string;
  caliber?: string;
  powder?: string;
  powderChargeGr?: number;
  bullet?: string;
  bulletWeightGr?: number;
  primer?: string;
  brass?: string;
  coalIn?: number;
  cbtoIn?: number;
  notes?: string;
}

export class AnthropicError extends Error {
  constructor(
    message: string,
    public readonly status: number,
  ) {
    super(message);
    this.name = 'AnthropicError';
  }
}

export async function callAnthropic(
  body: SmartImportRequest,
  apiKey: string,
): Promise<{ improved: ImprovedDraft; inputTokens: number; outputTokens: number }> {
  const userPrompt = buildUserPrompt(body);
  const requestBody = {
    model: body.model ?? 'claude-sonnet-4-5',
    max_tokens: 600,
    system: SYSTEM_PROMPT,
    messages: [{ role: 'user', content: userPrompt }],
  };

  const res = await fetch(ANTHROPIC_URL, {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': ANTHROPIC_VERSION,
      'content-type': 'application/json',
    },
    body: JSON.stringify(requestBody),
  });

  const json = (await res.json()) as Record<string, unknown>;

  if (!res.ok) {
    const err = (json.error as { message?: string } | undefined)?.message ??
      `HTTP ${res.status}`;
    throw new AnthropicError(err, res.status);
  }

  const content = json.content;
  const assistantText = extractAssistantText(content);
  if (!assistantText) {
    throw new AnthropicError('Anthropic returned no text content.', 502);
  }

  const usage = json.usage as { input_tokens?: number; output_tokens?: number } | undefined;
  const improved = parseImprovedDraft(assistantText);

  return {
    improved,
    inputTokens: usage?.input_tokens ?? 0,
    outputTokens: usage?.output_tokens ?? 0,
  };
}

function buildUserPrompt(body: SmartImportRequest): string {
  const initial = JSON.stringify(body.initial_draft ?? {});
  const hints = JSON.stringify(body.catalog_hints ?? {});
  return `OCR_TEXT:
${body.ocr_text}

INITIAL_DRAFT (from on-device parser, may have low-confidence fields):
${initial}

CATALOG_HINTS (known cartridges, powders, bullets — pick the closest match):
${hints}

Return a JSON object with this shape (omit any field you cannot improve):
{
  "recipeName": "...",
  "caliber": "...",
  "powder": "...",
  "powderChargeGr": 41.5,
  "bullet": "...",
  "bulletWeightGr": 140,
  "primer": "...",
  "brass": "...",
  "coalIn": 2.825,
  "cbtoIn": 2.215,
  "notes": "..."
}`;
}

function extractAssistantText(content: unknown): string {
  if (!Array.isArray(content)) return '';
  let out = '';
  for (const block of content) {
    if (
      block &&
      typeof block === 'object' &&
      'type' in block &&
      (block as { type: unknown }).type === 'text' &&
      'text' in block &&
      typeof (block as { text: unknown }).text === 'string'
    ) {
      out += (block as { text: string }).text;
    }
  }
  return out.trim();
}

function parseImprovedDraft(text: string): ImprovedDraft {
  // Strip a fenced ```json ... ``` block if present.
  let json = text.trim();
  const fence = /^```(?:json)?\s*/i;
  if (fence.test(json)) {
    json = json.replace(fence, '');
    if (json.endsWith('```')) {
      json = json.slice(0, -3);
    }
    json = json.trim();
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch (e) {
    throw new AnthropicError(`AI returned invalid JSON: ${(e as Error).message}`, 502);
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new AnthropicError('AI did not return a JSON object.', 502);
  }
  return parsed as ImprovedDraft;
}

export function diffFields(
  initial: Record<string, unknown>,
  improved: ImprovedDraft,
): string[] {
  const changed: string[] = [];
  const keys: (keyof ImprovedDraft)[] = [
    'recipeName',
    'caliber',
    'powder',
    'powderChargeGr',
    'bullet',
    'bulletWeightGr',
    'primer',
    'brass',
    'coalIn',
    'cbtoIn',
    'notes',
  ];
  for (const k of keys) {
    const next = improved[k];
    if (next === undefined) continue;
    const prev = initial[k as string];
    if (next !== prev) {
      changed.push(k);
    }
  }
  return changed;
}
