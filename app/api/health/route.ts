import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = await createClient();
  if (!supabase) return Response.json({ ok: false, service: "milky-events", reason: "supabase_not_configured" }, { status: 503 });

  const { count, error } = await supabase.from("categories").select("id", { count: "exact", head: true }).eq("active", true);
  if (error || count === null || count < 12) {
    return Response.json({ ok: false, service: "milky-events", reason: "database_not_ready" }, { status: 503 });
  }
  return Response.json({ ok: true, service: "milky-events", categories: count });
}
