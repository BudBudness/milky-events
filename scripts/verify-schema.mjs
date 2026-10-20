import { readFileSync } from "node:fs";

const migrationPath = new URL("../supabase/migrations/20261020125000_milky_events_core.sql", import.meta.url);
const sql = readFileSync(migrationPath, "utf8");
const requiredTables = [
  "profiles", "categories", "organizers", "venues", "organizer_payment_methods",
  "events", "ticket_types", "orders", "order_items", "transactions", "tickets",
  "check_ins", "platform_fee_rules", "platform_fees", "platform_fee_payments", "audit_logs",
];

for (const table of requiredTables) {
  if (!sql.includes(`create table public.${table} (`)) {
    throw new Error(`Missing required table: ${table}`);
  }
  if (!sql.includes(`alter table public.${table} enable row level security;`)) {
    throw new Error(`RLS is not explicitly enabled for ${table}`);
  }
}

const categorySeedCount = (sql.match(/^\('\S+','[^']+','[^']+'\)/gm) ?? []).length;
if (categorySeedCount < 12) {
  throw new Error(`Expected 12 seeded categories; found ${categorySeedCount}`);
}

for (const invariant of [
  "unique (user_id, idempotency_key)",
  "provider_reference text not null unique",
  "unique (ticket_id)",
  "check (ends_at > starts_at)",
  "check (sold_quantity >= 0 and sold_quantity <= quantity)",
  "percentage_bps integer not null default 0",
  "'event_goer'::public.profile_role",
]) {
  if (!sql.includes(invariant)) throw new Error(`Missing schema invariant: ${invariant}`);
}

console.log(`Milky Events schema contract passed: ${requiredTables.length} tables have RLS, 12 categories are seeded, and core uniqueness/validation invariants are present.`);
