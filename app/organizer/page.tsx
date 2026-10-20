import Link from "next/link";
import { submitOrganizerApplication } from "@/app/actions";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function OrganizerPage({ searchParams }: {
  searchParams: Promise<{ error?: string; submitted?: string; event_submitted?: string }>;
}) {
  const query = await searchParams;
  const supabase = await createClient();
  let signedIn = false;
  let organizer: { id: string; name: string; status: string } | null = null;
  if (supabase) {
    const { data: { user } } = await supabase.auth.getUser();
    signedIn = Boolean(user);
    if (user) {
      const { data } = await supabase.from("organizers").select("id,name,status").eq("user_id", user.id).maybeSingle();
      if (data) organizer = data as { id: string; name: string; status: string };
    }
  }

  return <main className="container">
    <header className="nav"><Link href="/" className="brand">milky<span>events</span></Link><Link href="/">← Back to discovery</Link></header>
    <section className="form-wrap">
      <p className="eyebrow">For local organizers</p><h1 style={{fontSize:42}}>Bring people together.</h1>
      <p className="lead" style={{fontSize:16}}>Apply to host events, publish your details after review, and configure the payment methods you use to receive ticket revenue directly.</p>
      {!supabase && <div className="notice">Supabase is not configured. Set the production environment variables before using organizer registration.</div>}
      {query.error && <div className="notice">We could not complete the request. Check the details or contact platform support.</div>}
      {query.submitted && <div className="notice">Your organizer application was submitted for review.</div>}
      {query.event_submitted && <div className="notice">Your event and ticket type were submitted together for review. The event will not appear publicly until approved.</div>}
      {!signedIn ? <p>Sign in or create an event-goer account first, then submit your organizer application. <Link href="/login" style={{color:"var(--green)",fontWeight:700}}>Sign in →</Link></p>
      : organizer?.status === "approved" ? <>
        <h2 style={{fontSize:25}}>Organizer workspace</h2>
        <p>Account: <strong>{organizer.name}</strong> · Approved</p>
        <p>Create an event with a ticket type. Paid events require a verified active payment destination.</p>
        <Link className="button" href="/organizer/events/new">Submit an event</Link>
        <p style={{fontSize:13,color:"var(--muted)",marginTop:18}}>Event publication requires internal review. Customer ticket payments go directly to your verified destination.</p>
      </> : organizer?.status === "pending" ? <>
        <div className="notice">Your organizer application is awaiting review. Event publishing tools unlock after approval.</div>
        <p>Application: <strong>{organizer.name}</strong> · Pending</p>
      </> : organizer?.status === "suspended" ? <div className="notice">This organizer account is suspended. Contact Milky Events support for review.</div>
      : <form action={submitOrganizerApplication}>
        <label className="field">Organizer or business name<input name="name" minLength={2} required maxLength={160}/></label>
        <label className="field">About your events<textarea name="description" maxLength={2000}/></label>
        <label className="field">Public contact phone<input name="contact_phone" required minLength={7} maxLength={40}/></label>
        <button type="submit" disabled={!supabase}>Submit organizer application</button>
      </form>}
      <p style={{marginTop:20,fontSize:13,color:"var(--muted)"}}>Applications are reviewed before paid events can be published. Milky Events does not hold customer ticket revenue.</p>
    </section>
  </main>;
}
