import Link from "next/link";
import { redirect } from "next/navigation";
import { submitEventWithTicket } from "@/app/actions";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function NewOrganizerEventPage({ searchParams }: {
  searchParams: Promise<{ error?: string }>;
}) {
  const query = await searchParams;
  const supabase = await createClient();
  if (!supabase) redirect("/organizer?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?next=/organizer/events/new");

  const { data: organizer } = await supabase.from("organizers").select("id,status").eq("user_id", user.id).maybeSingle();
  if (!organizer || organizer.status !== "approved") redirect("/organizer?error=not_approved");

  const [{ data: categories }, { data: venues }, { data: paymentMethods }] = await Promise.all([
    supabase.from("categories").select("id,name").eq("active", true).order("name"),
    supabase.from("venues").select("id,name,area").eq("organizer_id", organizer.id).order("name"),
    supabase.from("organizer_payment_methods").select("id,provider,account_name,method").eq("organizer_id", organizer.id).eq("active", true).eq("verification_status", "verified").order("created_at"),
  ]);

  return <main className="container">
    <header className="nav"><Link href="/" className="brand">milky<span>events</span></Link><Link href="/organizer">← Organizer workspace</Link></header>
    <section className="form-wrap">
      <p className="eyebrow">Event submission</p><h1 style={{fontSize:42}}>List your event.</h1>
      <p className="lead" style={{fontSize:16}}>The event and its first ticket type are saved atomically. They remain pending until the platform review is complete.</p>
      {query.error && <div className="notice">The event could not be submitted. Verify the details, future dates, inventory, and payment destination.</div>}
      <form action={submitEventWithTicket}>
        <label className="field">Event title<input name="title" required minLength={3} maxLength={180}/></label>
        <label className="field">Description<textarea name="description" maxLength={5000}/></label>
        <div className="form-grid">
          <label className="field">Category<select name="category_id" required defaultValue=""><option value="" disabled>Select a category</option>{(categories ?? []).map((item:any)=><option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
          <label className="field">Venue<select name="venue_id" defaultValue=""><option value="">Venue to be confirmed</option>{(venues ?? []).map((item:any)=><option key={item.id} value={item.id}>{item.name}{item.area ? ` · ${item.area}` : ""}</option>)}</select></label>
          <label className="field">Starts (Uganda time)<input name="starts_at" type="datetime-local" required/></label>
          <label className="field">Ends (Uganda time)<input name="ends_at" type="datetime-local" required/></label>
          <label className="field">Ticket name<input name="ticket_name" required minLength={1} maxLength={100} defaultValue="General admission"/></label>
          <label className="field">Ticket price (UGX)<input name="price_ugx" type="number" required min="0" step="1" defaultValue="0"/></label>
          <label className="field">Ticket quantity<input name="quantity" type="number" required min="1" max="100000" step="1" defaultValue="100"/></label>
          <label className="field">Verified payment destination<select name="payment_method_id" defaultValue=""><option value="">Not needed for free tickets</option>{(paymentMethods ?? []).map((item:any)=><option key={item.id} value={item.id}>{item.provider} · {item.account_name} ({item.method})</option>)}</select></label>
        </div>
        {!(paymentMethods ?? []).length && <div className="notice">No verified payment method is active. You can submit a free event now; paid ticket sales stay blocked until a payment destination is verified.</div>}
        <button type="submit">Submit event for review</button>
      </form>
    </section>
  </main>;
}
