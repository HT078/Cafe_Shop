import { createClient } from 'npm:@supabase/supabase-js@2';

type SePayPayload = {
  id?: number | string;
  gateway?: string;
  transactionDate?: string;
  accountNumber?: string;
  subAccount?: string;
  code?: string | null;
  content?: string;
  description?: string;
  transferType?: string;
  transferAmount?: number | string;
  referenceCode?: string;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const webhookSecret = Deno.env.get('SEPAY_WEBHOOK_SECRET') ?? '';

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ success: false, message: 'Method not allowed' }, 405);
  }

  if (!supabaseUrl || !serviceRoleKey || !webhookSecret) {
    console.error('Missing Supabase or SePay webhook secrets');
    return jsonResponse({ success: false, message: 'Server configuration error' }, 500);
  }

  const rawBody = await request.text();
  const timestamp = request.headers.get('x-sepay-timestamp')?.trim() ?? '';
  const signature = request.headers.get('x-sepay-signature')?.trim() ?? '';

  if (!timestamp || !signature) {
    return jsonResponse({ success: false, message: 'Missing signature' }, 401);
  }

  const signatureIsValid = await verifySignature(
    rawBody,
    timestamp,
    signature,
    webhookSecret,
  );
  if (!signatureIsValid) {
    return jsonResponse({ success: false, message: 'Invalid signature' }, 401);
  }

  let payload: SePayPayload;
  try {
    payload = JSON.parse(rawBody) as SePayPayload;
  } catch (_) {
    return jsonResponse({ success: false, message: 'Invalid JSON' }, 400);
  }

  const transactionId = Number(payload.id ?? 0);
  const transferAmount = Number(payload.transferAmount ?? 0);
  const transferType = payload.transferType?.trim().toLowerCase() ?? '';

  if (!Number.isSafeInteger(transactionId) || transactionId <= 0) {
    return jsonResponse({ success: false, message: 'Invalid transaction id' }, 400);
  }

  if (transferType !== 'in') {
    return jsonResponse({ success: true, message: 'Ignored outgoing transaction' });
  }

  if (!Number.isFinite(transferAmount) || transferAmount <= 0) {
    return jsonResponse({ success: false, message: 'Invalid amount' }, 400);
  }

  const paymentCode = detectPaymentCode(payload);
  if (!paymentCode) {
    console.warn(`Transaction ${transactionId}: order code not found`);
    return jsonResponse({ success: true, message: 'Order code not found' });
  }

  const { data: result, error } = await supabase.rpc('process_sepay_payment', {
    p_transaction_id: transactionId,
    p_reference_code: payload.referenceCode?.trim() || null,
    p_transfer_amount: Math.round(transferAmount),
    p_transfer_type: transferType,
    p_account_number: payload.accountNumber?.trim() ?? '',
    p_payment_code: paymentCode,
    p_payload: payload,
  });

  if (error) {
    console.error('process_sepay_payment failed', error);
    return jsonResponse({ success: false, message: error.message }, 500);
  }

  console.info(`Processed SePay transaction ${transactionId}`, result);
  return jsonResponse({ success: true, result });
});

function detectPaymentCode(payload: SePayPayload): string | null {
  const rawCode = normalize(payload.code);
  if (/^DH[A-Z0-9]{8}$/.test(rawCode)) return rawCode;
  if (/^[A-Z0-9]{8}$/.test(rawCode)) return `DH${rawCode}`;
  if (/^HT\d{8}\d{3}$/.test(rawCode)) return rawCode;

  const text = [payload.content, payload.description]
    .filter(Boolean)
    .join(' ')
    .toUpperCase();

  const currentCode = text.match(/\bDH[\s:_-]*([A-Z0-9]{8})\b/);
  if (currentCode) return `DH${currentCode[1]}`;

  const legacyCode = text.match(/\bHT-\d{8}-\d{3}(?:-[A-Z0-9]+)?\b/);
  return legacyCode?.[0] ?? null;
}

async function verifySignature(
  rawBody: string,
  timestamp: string,
  signatureHeader: string,
  secret: string,
): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signed = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(`${timestamp}.${rawBody}`),
  );
  const expected = `sha256=${toHex(new Uint8Array(signed))}`;
  return constantTimeEquals(expected, signatureHeader.toLowerCase());
}

function constantTimeEquals(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function normalize(value: unknown): string {
  return String(value ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}
