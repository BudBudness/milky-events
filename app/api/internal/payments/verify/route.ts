import { timingSafeEqual } from "node:crypto";
import { createAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function safeEqual(a: string, b: string) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

export async function POST(request: Request) {
  const expectedToken = process.env.MILKY_INTERNAL_API_TOKEN;
  if (!expectedToken) {
    return Response.json({ error: "Internal payment verification is not configured" }, { status: 503 });
  }
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!token || !safeEqual(token, expectedToken)) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const supabase = createAdminClient();
  if (!supabase) {
    return Response.json({ error: "Payment verification service is not configured" }, { status: 503 });
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const orderId = String(body.order_id ?? "");
  const provider = String(body.provider ?? "").trim();
  const reference = String(body.provider_reference ?? "").trim();
  const amount = body.amount_ugx;
  const source = String(body.verification_source ?? "MANUAL_REFERENCE");
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuid.test(orderId) || provider.length < 2 || provider.length > 80 ||
      reference.length < 4 || reference.length > 160 || !Number.isSafeInteger(amount) ||
      Number(amount) < 0 || !["PROVIDER", "MANUAL_REFERENCE"].includes(source)) {
    return Response.json({ error: "Invalid payment verification payload" }, { status: 400 });
  }

  const { data, error } = await supabase.rpc("verify_ticket_order_payment", {
    p_order_id: orderId,
    p_provider: provider,
    p_provider_reference: reference,
    p_amount_ugx: Number(amount),
    p_verification_source: source,
  });
  if (error) {
    return Response.json({ error: "Payment verification rejected" }, { status: 409 });
  }
  return Response.json({ ok: true, order_id: data });
}
