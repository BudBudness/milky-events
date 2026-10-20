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
  if (!expectedToken) return Response.json({ error: "Internal configuration is not configured" }, { status: 503 });
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!token || !safeEqual(token, expectedToken)) return Response.json({ error: "Unauthorized" }, { status: 401 });
  const supabase = createAdminClient();
  if (!supabase) return Response.json({ error: "Configuration service is not configured" }, { status: 503 });

  let body: Record<string, unknown>;
  try { body = await request.json(); } catch { return Response.json({ error: "Invalid JSON body" }, { status: 400 }); }
  const action = String(body.action ?? "");
  if (action === "category") {
    const categoryId = String(body.category_id ?? "");
    const active = body.active;
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuid.test(categoryId) || typeof active !== "boolean") {
      return Response.json({ error: "Invalid category configuration" }, { status: 400 });
    }
    const { data, error } = await supabase.rpc("set_category_active", { p_category_id: categoryId, p_active: active });
    if (error) return Response.json({ error: "Category update rejected" }, { status: 409 });
    return Response.json({ ok: true, action, category_id: data });
  }

  if (action === "fee_rule") {
    const ruleId = body.rule_id ? String(body.rule_id) : null;
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    const name = String(body.name ?? "").trim();
    const percentage = body.percentage_bps;
    const fixed = body.fixed_amount_ugx;
    const basis = String(body.basis ?? "");
    const freePolicy = String(body.free_event_policy ?? "");
    const refundPolicy = String(body.refund_policy ?? "reverse_on_full_refund").trim();
    const payableRule = String(body.payable_rule ?? "after_ticket_sale").trim();
    const effectiveFrom = String(body.effective_from ?? new Date().toISOString());
    const effectiveTo = body.effective_to ? String(body.effective_to) : null;
    const active = body.active;
    if ((ruleId && !uuid.test(ruleId)) || name.length < 2 || name.length > 120 ||
        !Number.isInteger(percentage) || Number(percentage) < 0 || Number(percentage) > 10000 ||
        !Number.isSafeInteger(fixed) || Number(fixed) < 0 ||
        !["per_ticket", "per_order"].includes(basis) ||
        !["waived", "fixed"].includes(freePolicy) ||
        refundPolicy.length < 2 || refundPolicy.length > 120 ||
        payableRule.length < 2 || payableRule.length > 120 ||
        !Number.isFinite(Date.parse(effectiveFrom)) ||
        (effectiveTo !== null && !Number.isFinite(Date.parse(effectiveTo))) ||
        typeof active !== "boolean") {
      return Response.json({ error: "Invalid fee rule configuration" }, { status: 400 });
    }
    const { data, error } = await supabase.rpc("upsert_platform_fee_rule", {
      p_rule_id: ruleId,
      p_name: name,
      p_percentage_bps: Number(percentage),
      p_fixed_amount_ugx: Number(fixed),
      p_basis: basis,
      p_free_event_policy: freePolicy,
      p_refund_policy: refundPolicy,
      p_payable_rule: payableRule,
      p_effective_from: effectiveFrom,
      p_effective_to: effectiveTo,
      p_active: active,
    });
    if (error) return Response.json({ error: "Fee rule update rejected" }, { status: 409 });
    return Response.json({ ok: true, action, rule_id: data });
  }

  return Response.json({ error: "Unsupported configuration action" }, { status: 400 });
}
