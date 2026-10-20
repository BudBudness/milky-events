import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const supabase = await createClient();
  if (!supabase) return Response.json({ error: "Service not configured" }, { status: 503 });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return Response.json({ error: "Authentication required" }, { status: 401 });

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const code = String(body.unique_code ?? "").trim();
  const eventId = String(body.event_id ?? "");
  const method = String(body.method ?? "qr");
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (code.length < 8 || code.length > 64 || !uuid.test(eventId) ||
      !["qr", "ticket_code", "order_reference", "phone", "offline_sync"].includes(method)) {
    return Response.json({ error: "Invalid check-in payload" }, { status: 400 });
  }

  const { data, error } = await supabase.rpc("check_in_ticket", {
    p_unique_code: code,
    p_event_id: eventId,
    p_method: method,
  });
  if (error) return Response.json({ error: "Ticket check-in rejected" }, { status: 409 });
  return Response.json({ ok: true, ticket_id: data });
}
