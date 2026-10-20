import Link from "next/link";
import { redirect } from "next/navigation";
import { checkInTicket } from "@/app/actions";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function CheckInPage({ searchParams }: { searchParams: Promise<{ error?: string; checked_in?: string }> }) {
  const query = await searchParams;
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?next=/organizer/check-in");
  const { data: organizer } = await supabase.from("organizers").select("id,status").eq("user_id", user.id).maybeSingle();
  if (!organizer || organizer.status !== "approved") redirect("/organizer?error=not_approved");
  const { data: events } = await supabase.from("events").select("id,title,starts_at").eq("organizer_id", organizer.id).in("status", ["published","completed"]).order("starts_at",{ascending:false});

  return <main className="container">
    <header className="nav"><Link href="/" className="brand">milky<span>events</span></Link><Link href="/organizer">← Organizer workspace</Link></header>
    <section className="form-wrap">
      <p className="eyebrow">Door operations</p><h1 style={{fontSize:40}}>Check in a ticket.</h1>
      <p className="lead" style={{fontSize:16}}>The server validates event ownership and payment status, then marks a valid ticket as used atomically. Duplicate check-ins are rejected.</p>
      {query.error && <div className="notice">Check-in was rejected. Confirm the event and ticket code; the ticket may already have been used.</div>}
      {query.checked_in && <div className="notice">Ticket accepted. Check-in was recorded.</div>}
      <form action={checkInTicket}>
        <label className="field">Event<select name="event_id" required defaultValue=""><option value="" disabled>Select an event</option>{(events ?? []).map((event:any)=><option key={event.id} value={event.id}>{event.title}</option>)}</select></label>
        <label className="field">Ticket code<input name="unique_code" required minLength={8} maxLength={64} autoComplete="off"/></label>
        <label className="field">Scan method<select name="method" defaultValue="ticket_code"><option value="qr">QR scan</option><option value="ticket_code">Ticket code</option><option value="order_reference">Order reference</option><option value="phone">Phone lookup</option></select></label>
        <button type="submit">Validate and check in</button>
      </form>
    </section>
  </main>;
}
