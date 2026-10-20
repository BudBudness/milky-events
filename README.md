# Milky Events

Mbarara-first event discovery and digital ticketing platform powered by Pyong Recordz Ltd.

## V1 product boundaries

- Public roles: Event-goer and Organizer only.
- Internal platform operations are private and are not a public role.
- Event discovery is mobile-first and starts in Mbarara.
- Customer ticket payments go directly to organizers through verified organizer payment methods.
- Milky Events calculates and tracks its platform fees separately; it does not custody customer ticket revenue.
- QR ticketing, one-time server-side check-in, payment verification and fee reconciliation must be server-authoritative and idempotent.
- No autonomous agents are part of the core transaction path.

## Stack

- Next.js App Router + TypeScript
- Supabase Auth + PostgreSQL + RLS
- GitHub Actions CI
- Vercel deployment

## Local development

1. Use Node.js 22 or later.
2. Install dependencies with `npm install`.
3. Copy `.env.example` to `.env.local` and configure the Supabase URL and publishable key.
4. Apply `supabase/migrations/20261020125000_milky_events_core.sql` to the intended Supabase project.
5. Run `npm run dev`.

The home page remains buildable without secrets for CI, but account and operational workflows require a configured Supabase project. Never expose `SUPABASE_SECRET_KEY` or `MILKY_INTERNAL_API_TOKEN` to the browser.

## Payment model

Customer ticket payments are sent to an organizer's verified payment destination. A ticket must not be issued from client-side payment success alone. Provider callbacks or authorized manual-reference verification must validate the amount, order, reference and current state before ticket issuance. Duplicate references and repeated callbacks must not create duplicate tickets.

Organizer platform fees are paid separately to Milky Events. The payment destinations documented in `docs/BASE44.md` are for platform fees only, never customer ticket payments.

## Release status

The Next.js discovery and organizer application UI, schema contract checks, atomic order reservation/cancellation, pending payment-reference submission, trusted payment verification, ticket issuance and one-time organizer check-in RPCs are implemented in source. This is not yet a production release: the migration has not been applied to a dedicated Milky Events Supabase project; these database functions must be tested against that live project; fee-payment reconciliation, refunds and offline check-in remain incomplete; internal secrets must be configured; and Vercel production deployment/health checks must pass.
