import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { createTicketOrder } from "@/app/actions";

export const dynamic = "force-dynamic";

function formatDate(value: string) {
  return new Intl.DateTimeFormat("en-UG", {
    dateStyle: "full", timeStyle: "short", timeZone: "Africa/Kampala",
  }).format(new Date(value));
}

export default async function EventDetailsPage({ params, searchParams }: {
  params: Promise<{ eventId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { eventId } = await params;
  const { error: queryError } = await searchParams;
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");

  const { data: event } = await supabase.from("events")
    .select("id,title,description,starts_at,ends_at,categories(name),venues(name,address,area),organizers(name),organizer_payment_methods(method,provider,account_identifier,account_name,verification_status,active),ticket_types(id,name,description,price_ugx,quantity,sold_quantity,active)")
    .eq("id", eventId)
    .eq("status", "published")
    .single();

  if (!event) notFound();
  const row = event as any;
  const paymentMethod = Array.isArray(row.organizer_payment_methods) ? row.organizer_payment_methods[0] : row.organizer_payment_methods;
  const tickets = (row.ticket_types ?? []).filter((ticket: any) => ticket.active);
  const { data: { user } } = await supabase.auth.getUser();

  return <main className="container">
    <header className="nav"><Link href="/" className="brand">milky<span>events</span></Link><Link href="/">← All events</Link></header>
    <section className="form-wrap">
      <p className="eyebrow">{row.categories?.name ?? "Local event"} · {row.organizers?.name ?? "Local organizer"}</p>
      <h1 style={{fontSize:42}}>{row.title}</h1>
      <p className="lead" style={{fontSize:16}}>{row.description || "Event details will be shared by the organizer."}</p>
      <div className="pills"><span className="pill">{formatDate(row.starts_at)}</span><span className="pill">{row.venues?.name ?? "Venue to be confirmed"}</span>{row.venues?.area && <span className="pill">{row.venues.area}</span>}</div>
      {row.venues?.address && <p style={{marginTop:16,color:"var(--muted)"}}>{row.venues.address}</p>}
      {queryError && <div className="notice">We could not create that order. Check availability and try again.</div>}
      <h2 style={{fontSize:26,marginTop:32}}>Choose your ticket</h2>
      {!user && <div className="notice">Sign in to reserve tickets. Ticket orders are created securely on the server.</div>}
      <div style={{display:"grid",gap:12}}>
        {tickets.map((ticket: any) => {
          const remaining = Math.max(0, Number(ticket.quantity) - Number(ticket.sold_quantity));
          return <article key={ticket.id} className="event-card" style={{minHeight:0}}>
            <div style={{display:"flex",justifyContent:"space-between",gap:16,alignItems:"start"}}>
              <div><h3>{ticket.name}</h3><p>{ticket.description || (Number(ticket.price_ugx) === 0 ? "Free admission" : "Digital event ticket")}</p><strong>{Number(ticket.price_ugx) === 0 ? "Free" : `UGX ${Number(ticket.price_ugx).toLocaleString("en-UG")}`}</strong><p style={{fontSize:12,marginTop:8}}>{remaining} remaining</p></div>
              {user && remaining > 0 && <form action={createTicketOrder} style={{minWidth:130}}>
                <input type="hidden" name="event_id" value={row.id}/>
                <input type="hidden" name="ticket_type_id" value={ticket.id}/>
                <input type="hidden" name="idempotency_key" value={randomUUID()}/>
                <label className="field">Quantity<select name="quantity" defaultValue="1">{Array.from({length:Math.min(10,remaining)},(_,i)=>i+1).map(n=><option key={n} value={n}>{n}</option>)}</select></label>
                <button type="submit">Reserve</button>
              </form>}
            </div>
          </article>;
        })}
      </div>
      {paymentMethod && <div className="notice" style={{marginTop:24}}>Payment destination: <strong>{paymentMethod.provider}</strong> · {paymentMethod.account_name} · {paymentMethod.account_identifier}. Payment is verified before paid tickets are issued.</div>}
      {!paymentMethod && tickets.some((ticket: any)=>Number(ticket.price_ugx)>0) && <div className="notice">Paid tickets are temporarily unavailable because the event has no active verified payment destination.</div>}
    </section>
  </main>;
}
