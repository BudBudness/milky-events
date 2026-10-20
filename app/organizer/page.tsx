import Link from "next/link";
import { submitOrganizerApplication } from "@/app/actions";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function OrganizerPage() {
  const supabase = await createClient();
  let signedIn = false;
  if (supabase) {
    const { data } = await supabase.auth.getUser();
    signedIn = Boolean(data.user);
  }
  return <main className="container">
    <header className="nav"><Link href="/" className="brand">milky<span>events</span></Link><Link href="/">← Back to discovery</Link></header>
    <section className="form-wrap">
      <p className="eyebrow">For local organizers</p><h1 style={{fontSize:42}}>Bring people together.</h1>
      <p className="lead" style={{fontSize:16}}>Apply to host events, publish your details after review, and configure the payment methods you use to receive ticket revenue directly.</p>
      {!supabase && <div className="notice">Supabase is not configured. Set the production environment variables before using organizer registration.</div>}
      {!signedIn ? <p>Sign in or create an event-goer account first, then submit your organizer application.</p> : <form action={submitOrganizerApplication}>
        <label className="field">Organizer or business name<input name="name" minLength={2} required maxLength={160}/></label>
        <label className="field">About your events<textarea name="description" maxLength={2000}/></label>
        <label className="field">Public contact phone<input name="contact_phone" required minLength={7} maxLength={40}/></label>
        <button type="submit">Submit organizer application</button>
      </form>}
      <p style={{marginTop:20,fontSize:13,color:"var(--muted)"}}>Applications are reviewed before paid events can be published. Milky Events does not hold customer ticket revenue.</p>
    </section>
  </main>;
}
