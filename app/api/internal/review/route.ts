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
  if (!expectedToken) return Response.json({ error: "Internal review is not configured" }, { status: 503 });
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!token || !safeEqual(token, expectedToken)) return Response.json({ error: "Unauthorized" }, { status: 401 });
  const supabase = createAdminClient();
  if (!supabase) return Response.json({ error: "Review service is not configured" }, { status: 503 });

  let body: Record<string, unknown>;
  try { body = await request.json(); } catch { return Response.json({ error: "Invalid JSON body" }, { status: 400 }); }
  const action = String(body.action ?? "");
  const id = String(body.id ?? "");
  const approve = body.approve;
  const reason = String(body.reason ?? "").slice(0, 1000);
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const procedures: Record<string, { name: string; idArg: string }> = {
    organizer: { name: "review_organizer_application", idArg: "p_organizer_id" },
    event: { name: "review_event_submission", idArg: "p_event_id" },
    payment_method: { name: "review_organizer_payment_method", idArg: "p_method_id" },
    platform_fee_payment: { name: "review_platform_fee_payment", idArg: "p_payment_id" },
  };
  const procedure = procedures[action];
  if (!procedure || !uuid.test(id) || typeof approve !== "boolean") {
    return Response.json({ error: "Invalid review payload" }, { status: 400 });
  }

  const args: Record<string, unknown> = { [procedure.idArg]: id, p_approve: approve, p_reason: reason || null };
  const { data, error } = await supabase.rpc(procedure.name as never, args as never);
  if (error) return Response.json({ error: "Review rejected" }, { status: 409 });
  return Response.json({ ok: true, action, id: data });
}
