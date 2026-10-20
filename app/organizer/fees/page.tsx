import Link from "next/link";
import { redirect } from "next/navigation";
import { submitPlatformFeePayment } from "@/app/actions";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

function money(value: number) { return `UGX ${value.toLocaleString("en-UG")}`; }

export default async function OrganizerFeesPage({ searchParams }: { searchParams: Promise<{ error?: string; submitted?: string }> }) {
  const query = await searchParams;
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?next=/organizer/fees");
  const { data: organizer } = await supabase.from("organizers").select("id,name").eq("user_id", user.id).maybeSingle();
  if (!organizer) redirect("/organizer?error=application_required");

  const [{ data: fees }, { data: payments }] = await Promise.all([
    supabase.from("platform_fees").select("amount_ugx,status,created_at").eq("organizer_id", organizer.id),
    supabase.from("platform_fee_payments").select("amount_ugx,status,payment_method,payment_reference,submitted_at").eq("organizer_id", organizer.id).order("submitted_at",{ascending:false}),
  ]);
  const assessed = (fees ?? []).reduce((sum:any,fee:any)=>sum+Number(fee.amount_ugx),0);
  const verified = (payments ?? []).filter((payment:any)=>payment.status==="verified").reduce((sum:any,payment:any)=>sum+Number(payment.amount_ugx),0);
  const outstanding = Math.max(0,assessed-verified);

  return <main className="container">
    <header className="nav"><Link href="/" className="brand">milky<span>events</span></Link><Link href="/organizer">← Organizer workspace</Link></header>
    <section className="form-wrap">
      <p className="eyebrow">Platform fee ledger</p><h1 style={{fontSize:40}}>Organizer fees.</h1>
      <p className="lead" style={{fontSize:16}}>Platform fees are separate from customer ticket payments. Customers pay your verified destination; platform-fee payments go to Milky Events.</p>
      <div className="event-grid" style={{gridTemplateColumns:"repeat(3,minmax(0,1fr))"}}>
        <div className="event-card" style={{minHeight:0}}><p className="eyebrow">Assessed</p><h2 style={{fontSize:24}}>{money(assessed)}</h2></div>
        <div className="event-card" style={{minHeight:0}}><p className="eyebrow">Verified payments</p><h2 style={{fontSize:24}}>{money(verified)}</h2></div>
        <div className="event-card" style={{minHeight:0}}><p className="eyebrow">Outstanding</p><h2 style={{fontSize:24}}>{money(outstanding)}</h2></div>
      </div>
      {query.error && <div className="notice">The fee payment could not be submitted. Check the amount and reference.</div>}
      {query.submitted && <div className="notice">The platform-fee payment reference was submitted for verification. The ledger updates after confirmation.</div>}
      {!assessed && <div className="notice">No platform fees have been assessed yet. Fees are calculated only from an active, explicitly configured platform-fee rule.</div>}
      {outstanding > 0 && <form action={submitPlatformFeePayment}>
        <h2 style={{fontSize:24}}>Submit a platform-fee payment</h2>
        <label className="field">Amount paid (UGX)<input name="amount_ugx" type="number" min="1" step="1" max={outstanding} required/></label>
        <label className="field">Payment method<select name="payment_method" required defaultValue="airtel_money"><option value="airtel_money">Airtel Money</option><option value="bank_transfer">Bank transfer</option><option value="other">Other</option></select></label>
        <label className="field">Payment reference<input name="payment_reference" required minLength={4} maxLength={160}/></label>
        <button type="submit">Submit for verification</button>
      </form>}
      <h2 style={{fontSize:24,marginTop:28}}>Payment history</h2>
      {(payments ?? []).length ? <div style={{display:"grid",gap:10}}>{(payments ?? []).map((payment:any)=><article key={payment.payment_reference} className="event-card" style={{minHeight:0}}><strong>{money(Number(payment.amount_ugx))} · {payment.status}</strong><p>{payment.payment_method} · {payment.payment_reference}</p></article>)}</div> : <p style={{color:"var(--muted)"}}>No platform-fee payments submitted.</p>}
    </section>
  </main>;
}
