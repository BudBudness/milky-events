import Link from "next/link";
import { signIn, signUp } from "@/app/auth-actions";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function LoginPage() {
  const supabase = await createClient();
  return <main className="container">
    <header className="nav"><Link href="/" className="brand">milky<span>events</span></Link><Link href="/">← Back to discovery</Link></header>
    <section className="form-wrap">
      <p className="eyebrow">Your events, together</p><h1 style={{fontSize:42}}>Sign in or join.</h1>
      {!supabase && <div className="notice">Supabase is not configured. Set the required environment variables before enabling account access.</div>}
      <form action={signIn}>
        <label className="field">Email<input name="email" type="email" autoComplete="email" required maxLength={254}/></label>
        <label className="field">Password<input name="password" type="password" autoComplete="current-password" required minLength={12} maxLength={128}/></label>
        <button type="submit" disabled={!supabase}>Sign in</button>
      </form>
      <div style={{borderTop:"1px solid var(--line)",margin:"28px 0"}}/>
      <h2 style={{fontSize:24}}>New to Milky Events?</h2>
      <form action={signUp}>
        <label className="field">Display name<input name="display_name" required minLength={2} maxLength={100}/></label>
        <label className="field">Email<input name="email" type="email" autoComplete="email" required maxLength={254}/></label>
        <label className="field">Password<input name="password" type="password" autoComplete="new-password" required minLength={12} maxLength={128}/></label>
        <button type="submit" disabled={!supabase}>Create event-goer account</button>
      </form>
      <p style={{fontSize:13,color:"var(--muted)",marginTop:18}}>New accounts start as event-goers. Organizer applications are reviewed separately; client metadata cannot grant organizer or internal privileges.</p>
    </section>
  </main>;
}
