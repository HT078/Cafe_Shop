import { createClient } from 'npm:@supabase/supabase-js@2';

type SePayPayload = {
  id?: number | string;
  gateway?: string;
  transactionDate?: string;
  accountNumber?: string;
  code?: string | null;
  content?: string;
  transferType?: string;
  transferAmount?: number | string;
  referenceCode?: string;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const webhookApiKey = Deno.env.get('SEPAY_WEBHOOK_API_KEY') ?? '';

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ success: false }, 405);
  }

  if (!supabaseUrl || !serviceRoleKey || !webhookApiKey) {
    console.error('Missing Supabase or SePay webhook environment variables');
    return jsonResponse({ success: false }, 500);
  }

  const authorization = request.headers.get('authorization')?.trim() ?? '';
  if (authorization !== `Apikey ${webhookApiKey}`) {
    return jsonResponse({ success: false }, 401);
  }

  let payload: SePayPayload;
  try {
    payload = await request.json() as SePayPayload;
  } catch (_) {
    return jsonResponse({ success: false }, 400);
  }

  const transactionId = Number(payload.id ?? 0);
  const transferType = payload.transferType?.trim().toLowerCase() ?? '';
  const transferAmount = Number(payload.transferAmount ?? 0);

  if (
    !Number.isSafeInteger(transactionId) ||
    transactionId <= 0 ||
    transferType !== 'in' ||
    !Number.isFinite(transferAmount) ||
    transferAmount <= 0
  ) {
    return jsonResponse({ success: true });
  }

  const paymentCode = detectPaymentCode(payload.code, payload.content);
  if (!paymentCode) {
    console.warn(`Ignored SePay transaction ${transactionId}: no order code`);
    return jsonResponse({ success: true });
  }

  const { data: result, error: processError } = await supabase.rpc(
    'process_sepay_payment',
    {
      p_transaction_id: transactionId,
      p_reference_code: payload.referenceCode?.trim() || null,
      p_transfer_amount: Math.round(transferAmount),
      p_transfer_type: transferType,
      p_account_number: payload.accountNumber ?? '',
      p_payment_code: paymentCode,
      p_payload: payload,
    },
  );

  if (processError) {
    console.error('Cannot process SePay payment', processError);
    return jsonResponse({ success: false }, 500);
  }

  console.info(`Processed SePay transaction ${transactionId}`, result);

  // SePay requires exactly HTTP 200 and {"success":true}.
  return jsonResponse({ success: true });
});

function detectPaymentCode(
  rawCode: string | null | undefined,
  content: string | undefined,
): string | null {
  const code = normalize(rawCode);
  if (code) return code;

  const normalizedContent = (content ?? '').toUpperCase();
  return normalizedContent.match(/DH[A-Z0-9]{8}/)?.[0] ?? null;
}

function normalize(value: unknown): string {
  return String(value ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function jsonResponse(
  body: { success: boolean },
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}
