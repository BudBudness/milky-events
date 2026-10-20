import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type EventRow = {
  id: string;
  title: string;
  description: string | null;
  starts_at: string;
  ends_at: string;
  categories: { name: string } | null;
  venues: { name: string; area: string | null } | null;
  ticket_types: { price_ugx: number; quantity: number; sold_quantity: number }[];
};

const categories = [
  "Music & Nightlife", "Business & Networking", "Arts & Culture", "Food & Drink",
  "Sports & Fitness", "Education", "Family & Kids", "Faith & Community",
  "Health & Wellness", "Technology", "Markets & Shopping", "Charity & Causes",
];

function formatDate(value: string) {
  return new Intl.DateTimeFormat("en-UG", {
    dateStyle: "medium", timeStyle: "short", timeZone: "Africa/Kampala",
  }).format(new Date(value));
}

export default async function Home() {
  const supabase = await createClient();
  let events: EventRow[] = [];
  let setupRequired = !supabase;
  if (supabase) {
    const { data, error } = await supabase
      .from("events")
      .select("id,title,description,starts_at,ends_at,categories(name),venues(name,area),ticket_types(price_ugx,quantity,sold_quantity)")
      .eq("status", "published")
      .gte("ends_at", new Date().toISOString())
      .order("starts_at", { ascending: true })
      .limit(60);
    if (error) setupRequired = true;
    else events = (data ?? []) as unknown as EventRow[];
  }

  return (
    <main>
      <header className="container nav">
        <Link href="/" className="brand">milky<span>events</span></Link>
        <nav className="navlinks" aria-label="Main navigation">
          <a href="#discover">Discover</a>
          <a href="#categories">Categories</a>
          <Link href="/organizer">For organizers</Link>
          <Link href="/login" className="button">Sign in</Link>
        </nav>
      </header>
      <section className="container hero">
        <div>
          <p className="eyebrow">Mbarara first · Uganda next</p>
          <h1>Find your next good day.</h1>
          <p className="lead">Discover what is happening around you, book your place, and keep your digital tickets in one place.</p>
          <div className="pills"><span className="pill">Local events</span><span className="pill">Digital tickets</span><span className="pill">Verified payments</span></div>
          <p style={{marginTop:24}}><a className="button" href="#discover">Explore events ↓</a></p>
        </div>
        <aside className="hero-panel">
          <p className="eyebrow" style={{color:"var(--lime)"}}>The world, live</p>
          <div className="big">Your city.<br/>Your scene.</div>
          <p style={{lineHeight:1.6,color:"rgba(255,255,255,.82)"}}>From live music and markets to business meetups, community drives and family days.</p>
        </aside>
      </section>
      <section id="categories" className="container section" style={{paddingBottom:24}}>
        <p className="eyebrow">Explore by interest</p>
        <h2>Something for everyone.</h2>
        <div className="pills">{categories.map((category) => <span className="pill" key={category}>{category}</span>)}</div>
      </section>
      <section id="discover" className="container section">
        <div className="section-head"><div><p className="eyebrow">The local calendar</p><h2>Upcoming events</h2></div><Link href="/organizer">Host an event →</Link></div>
        {setupRequired && <div className="notice">Event discovery is awaiting the production Supabase configuration. Add the required environment variables and apply the database migration before launch.</div>}
        <div className="event-grid">
          {events.length ? events.map((event) => {
            const available = event.ticket_types.reduce((sum, ticket) => sum + Math.max(0, ticket.quantity - ticket.sold_quantity), 0);
            const prices = event.ticket_types.map((ticket) => Number(ticket.price_ugx));
            const lowest = prices.length ? Math.min(...prices) : null;
            return <article className="event-card" key={event.id}>
              <span className="category">{event.categories?.name ?? "Local event"}</span>
              <h3>{event.title}</h3><p>{event.description ?? "Event details will be shared by the organizer."}</p><Link href={`/events/${event.id}`} style={{marginTop:14,fontWeight:700,color:"var(--green)"}}>View tickets →</Link>
              <div className="event-meta">{formatDate(event.starts_at)}<br/>{event.venues?.name ?? "Venue to be confirmed"}{event.venues?.area ? ` · ${event.venues.area}` : ""}<br/>{lowest === null ? "Tickets not listed" : lowest === 0 ? "Free entry" : `From UGX ${lowest.toLocaleString("en-UG")}`} · {available} available</div>
            </article>;
          }) : <div className="empty"><h3>No upcoming events published yet</h3><p>Check back soon, or list your next event on Milky Events.</p><Link className="button" href="/organizer">List an event</Link></div>}
        </div>
      </section>
      <footer className="footer"><div className="container" style={{display:"flex",justifyContent:"space-between",gap:16,flexWrap:"wrap"}}><span>© {new Date().getFullYear()} Milky Events · Powered by Pyong Recordz Ltd.</span><span>Event discovery for Mbarara and beyond.</span></div></footer>
    </main>
  );
}
