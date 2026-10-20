import Link from "next/link";
import { redirect } from "next/navigation";
import { addOrganizerPaymentMethod } from "@/app/actions";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function NewPaymentMethodPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const query = await searchParams;
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?next=/organizer/payment-methods/new");
  const { data: organizer } = await supabase.from("organizers").select("id,name,status").eq("user_id", user.id).maybeSingle();
  if (!organizer) redirect("/organizer?error=application_required");

  return <main className="container">
    <header className="nav"><Link href="/" className="brand">milky<span>events</span></Link><Link href="/organizer">← Organizer workspace</Link></header>
    <section className="form-wrap">
      <p className="eyebrow">Organizer payments</p><h1 style={{fontSize:40}}>Add a payment destination.</h1>
      <p className="lead" style={{fontSize:16}}>Customer ticket payments go directly to your account. A destination stays inactive until the platform verifies it.</p>
      {query.error && <div className="notice">The payment destination could not be saved. Check the details and try again.</div>}
      <form action={addOrganizerPaymentMethod}>
        <label className="field">Method<select name="method" required defaultValue="airtel_money"><option value="airtel_money">Airtel Money</option><option value="mtn_momo">MTN Mobile Money</option><option value="bank_transfer">Bank transfer</option><option value="card">Card</option><option value="other">Other</option></select></label>
        <label className="field">Provider / bank name<input name="provider" required minLength={2} maxLength={80}/></label>
        <label className="field">Merchant / account identifier<input name="account_identifier" required minLength={3} maxLength={160}/></label>
        <label className="field">Account holder name<input name="account_name" required minLength={2} maxLength={160}/></label>
        <button type="submit">Submit for verification</button>
      </form>
    </section>
  </main>;
}
