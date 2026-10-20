import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { cancelTicketOrder, submitPaymentReference } from "@/app/actions";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

function money(value: number) {
  return value === 0 ? "Free" : `UGX ${value.toLocaleString("en-UG")}`;
}

export default async function OrderPage({ params, searchParams }: {
  params: Promise<{ orderId: string }>;
  searchParams: Promise<{ error?: string; reference_submitted?: string; cancelled?: string }>;
}) {
  const { orderId } = await params;
  const query = await searchParams;
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: order } = await supabase.from("orders")
    .select("id,event_id,total_amount_ugx,status,expires_at,created_at,events(title,starts_at,organizer_payment_methods(method,provider,account_identifier,account_name))")
    .eq("id", orderId).eq("user_id", user.id).single();
  if (!order) notFound();

  const [{ data: items }, { data: transactions }] = await Promise.all([
    supabase.from("order_items").select("id,quantity,unit_price_ugx,subtotal_ugx,ticket_types(name)").eq("order_id", order.id),
    supabase.from("transactions").select("provider,provider_reference,amount_ugx,status,created_at").eq("order_id", order.id).order("created_at",{ascending:false}),
  ]);
  const itemIds = (items ?? []).map((item: any) => item.id);
  const { data: tickets } = itemIds.length
    ? await supabase.from("tickets").select("id,order_item_id,unique_code,qr_payload,status,issued_at").in("order_item_id", itemIds)
    : { data: [] };
  const event = Array.isArray(order.events) ? order.events[0] : order.events;
  const eventPayment = event && (Array.isArray((event as any).organizer_payment_methods) ? (event as any).organizer_payment_methods[0] : (event as any).organizer_payment_methods);

  return <main className="container">
    <header className="nav"><Link href="/" className="brand">milky<span>events</span></Link><Link href="/">← Event discovery</Link></header>
    <section className="form-wrap">
      <p className="eyebrow">Order reference · {order.id.slice(0,8).toUpperCase()}</p>
      <h1 style={{fontSize:40}}>{(event as any)?.title ?? "Your ticket order"}</h1>
      <div className="pills"><span className="pill">Status: {order.status.replaceAll("_"," ")}</span><span className="pill">Total: {money(Number(order.total_amount_ugx))}</span></div>
      {query.error && <div className="notice">We could not complete that action. Check the details and try again.</div>}
      {query.reference_submitted && <div className="notice">Your payment reference was submitted for verification. Tickets are not issued until verification succeeds.</div>}
      {query.cancelled && <div className="notice">The pending order was cancelled and reserved inventory released.</div>}
      <h2 style={{fontSize:24,marginTop:28}}>Order items</h2>
      <div style={{display:"grid",gap:10}}>{(items ?? []).map((item: any)=><div key={item.id} className="event-card" style={{minHeight:0,display:"flex",flexDirection:"row",justifyContent:"space-between",gap:12}}><div><strong>{item.ticket_types?.name ?? "Ticket"}</strong><p style={{margin:"6px 0 0"}}>{item.quantity} × {money(Number(item.unit_price_ugx))}</p></div><strong>{money(Number(item.subtotal_ugx))}</strong></div>)}</div>
      {order.status === "payment_pending" && <>
        <h2 style={{fontSize:24,marginTop:30}}>Pay the organizer</h2>
        {eventPayment ? <div className="notice">Pay <strong>{money(Number(order.total_amount_ugx))}</strong> directly to the event organizer using <strong>{eventPayment.provider}</strong>. Account name: <strong>{eventPayment.account_name}</strong>. Destination: <strong>{eventPayment.account_identifier}</strong>. Milky Events does not collect the ticket money.</div> : <div className="notice">A verified payment destination is not currently available. Do not send money until the organizer's verified instructions are shown.</div>}
        <form action={submitPaymentReference}>
          <input type="hidden" name="order_id" value={order.id}/>
          <label className="field">Payment provider<input name="provider" required minLength={2} maxLength={80} placeholder="Airtel Money, MTN MoMo, bank"/></label>
          <label className="field">Transaction reference<input name="provider_reference" required minLength={4} maxLength={160}/></label>
          <label className="field">Amount paid (UGX)<input name="amount_ugx" type="number" required min="0" step="1" defaultValue={Number(order.total_amount_ugx)}/></label>
          <button type="submit">Submit for verification</button>
        </form>
        <form action={cancelTicketOrder} style={{marginTop:16}}><input type="hidden" name="order_id" value={order.id}/><button type="submit" style={{background:"#6d756f"}}>Cancel pending order</button></form>
      </>}
      {transactions && transactions.length > 0 && <><h2 style={{fontSize:24,marginTop:30}}>Payment verification</h2>{transactions.map((transaction:any)=><div key={transaction.provider_reference} className="event-card" style={{minHeight:0,marginBottom:10}}><strong>{transaction.provider} · {transaction.provider_reference}</strong><p>{money(Number(transaction.amount_ugx))} · {transaction.status}</p></div>)}</>}
      {order.status === "paid" && <><h2 style={{fontSize:24,marginTop:30}}>Your digital tickets</h2>{(tickets ?? []).map((ticket:any)=><div key={ticket.id} className="event-card" style={{minHeight:0,marginBottom:12}}><p className="eyebrow">Ticket code</p><h3>{ticket.unique_code}</h3><p>QR payload: <code>{ticket.qr_payload}</code></p><p>Status: {ticket.status}</p></div>)}<p style={{fontSize:13,color:"var(--muted)"}}>Keep these ticket codes private. Each ticket can be checked in once by an authorized organizer.</p></>}
    </section>
  </main>;
}
