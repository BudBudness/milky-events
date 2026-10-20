import { timingSafeEqual } from "node:crypto";
import { createAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function safeEqual(a: string, b: string) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

export async function GET(request: Request) {
  const expectedToken = process.env.CRON_SECRET || process.env.MILKY_INTERNAL_API_TOKEN;
  if (!expectedToken) return Response.json({ error: "Order expiry is not configured" }, { status: 503 });
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!token || !safeEqual(token, expectedToken)) return Response.json({ error: "Unauthorized" }, { status: 401 });
  const supabase = createAdminClient();
  if (!supabase) return Response.json({ error: "Order expiry service is not configured" }, { status: 503 });
  const { data, error } = await supabase.rpc("expire_ticket_orders");
  if (error) return Response.json({ error: "Order expiry failed" }, { status: 503 });
  return Response.json({ ok: true, expired_orders: data });
}
