import json
import os
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import psycopg
from psycopg import errors

DATABASE_URL = os.environ["DATABASE_URL"]
MIGRATION_PATH = os.path.join(os.path.dirname(__file__), "..", "supabase", "migrations", "20261020125000_milky_events_core.sql")


def claim(conn, role: str, user_id: str | None = None):
    conn.execute("SET LOCAL ROLE " + role)
    claims = {"role": role}
    if user_id:
        claims["sub"] = user_id
    conn.execute("SELECT set_config('request.jwt.claim.sub', %s, true)", (user_id or "",))
    conn.execute("SELECT set_config('request.jwt.claims', %s, true)", (json.dumps(claims),))


with psycopg.connect(DATABASE_URL, autocommit=True) as conn:
    conn.execute("CREATE ROLE anon NOLOGIN")
    conn.execute("CREATE ROLE authenticated NOLOGIN")
    conn.execute("CREATE ROLE service_role NOLOGIN BYPASSRLS")
    conn.execute("CREATE SCHEMA auth")
    conn.execute("""
      CREATE TABLE auth.users (
        id uuid PRIMARY KEY,
        raw_user_meta_data jsonb NOT NULL DEFAULT '{}'::jsonb
      )
    """)
    conn.execute("""
      CREATE FUNCTION auth.uid() RETURNS uuid
      LANGUAGE sql STABLE
      AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$
    """)
    conn.execute("""
      CREATE FUNCTION auth.jwt() RETURNS jsonb
      LANGUAGE sql STABLE
      AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb) $$
    """)
    conn.execute("GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role")
    conn.execute("GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role")
    conn.execute("GRANT EXECUTE ON FUNCTION auth.jwt() TO anon, authenticated, service_role")

    with open(MIGRATION_PATH, encoding="utf-8") as migration_file:
        migration_sql = migration_file.read()
    conn.execute(migration_sql, prepare=False)

    category_count = conn.execute("SELECT count(*) FROM public.categories WHERE active").fetchone()[0]
    assert category_count == 12, f"Expected 12 active categories, got {category_count}"
    rls_count = conn.execute("""
      SELECT count(*) FROM pg_tables
      WHERE schemaname = 'public' AND rowsecurity
        AND tablename::text = ANY(%s)
    """, ([
      "profiles", "categories", "organizers", "venues", "organizer_payment_methods",
      "events", "ticket_types", "orders", "order_items", "transactions", "tickets",
      "check_ins", "platform_fee_rules", "platform_fees", "platform_fee_payments", "audit_logs",
    ],)).fetchone()[0]
    assert rls_count == 16, f"Expected RLS on all 16 tables, got {rls_count}"

    buyer_id = str(uuid4())
    organizer_user_id = str(uuid4())
    conn.execute(
      "INSERT INTO auth.users (id, raw_user_meta_data) VALUES (%s, %s::jsonb), (%s, %s::jsonb)",
      (buyer_id, json.dumps({"display_name": "Test buyer"}), organizer_user_id, json.dumps({"display_name": "Test organizer"})),
    )
    organizer_id = str(uuid4())
    category_id = conn.execute("SELECT id FROM public.categories WHERE slug = 'music-nightlife'").fetchone()[0]
    payment_method_id = str(uuid4())
    venue_id = str(uuid4())

    conn.execute("""
      INSERT INTO public.organizers (id, user_id, name, contact_phone, status)
      VALUES (%s, %s, 'CI Test Organizer', '+256700000000', 'pending')
    """, (organizer_id, organizer_user_id))
    with conn.transaction():
        claim(conn, "service_role")
        conn.execute("SELECT public.review_organizer_application(%s, true, 'CI approval')", (organizer_id,))

    conn.execute("""
      INSERT INTO public.organizer_payment_methods
        (id, organizer_id, method, provider, account_identifier, account_name, verification_status, active)
      VALUES (%s, %s, 'airtel_money', 'Airtel Money', '0700000000', 'CI Test Organizer', 'pending', false)
    """, (payment_method_id, organizer_id))
    with conn.transaction():
        claim(conn, "service_role")
        conn.execute("SELECT public.review_organizer_payment_method(%s, true, 'CI verification')", (payment_method_id,))

    conn.execute("""
      INSERT INTO public.venues (id, organizer_id, name, address, area)
      VALUES (%s, %s, 'CI Venue', 'Test address', 'Mbarara')
    """, (venue_id, organizer_id))

    starts_at = datetime.now(timezone.utc) + timedelta(days=1)
    ends_at = datetime.now(timezone.utc) + timedelta(days=2)
    with conn.transaction():
        claim(conn, "authenticated", organizer_user_id)
        event_id = conn.execute("""
          SELECT public.submit_event_with_ticket(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (category_id, "CI Test Event", "Temporary integration-test event", venue_id,
              payment_method_id, starts_at, ends_at, "General", 10000, 5)).fetchone()[0]
    with conn.transaction():
        claim(conn, "service_role")
        conn.execute("SELECT public.review_event_submission(%s, true, 'CI publication')", (event_id,))
    ticket_type_id = conn.execute("SELECT id FROM public.ticket_types WHERE event_id = %s", (event_id,)).fetchone()[0]
    fee_rule_id = str(uuid4())
    conn.execute("""
      INSERT INTO public.platform_fee_rules
        (id, name, percentage_bps, fixed_amount_ugx, basis, free_event_policy, active, effective_from)
      VALUES (%s, 'CI test rule', 500, 1000, 'per_order', 'waived', true, now())
    """, (fee_rule_id,))

    # Public discovery is available; private financial records are not granted to anon.
    with conn.transaction():
        claim(conn, "anon")
        public_events = conn.execute("SELECT count(*) FROM public.events WHERE status = 'published'").fetchone()[0]
        assert public_events == 1
        assert conn.execute("SELECT has_table_privilege('anon', 'public.orders', 'SELECT')").fetchone()[0] is False

    # Idempotent order creation reserves inventory exactly once.
    with conn.transaction():
        claim(conn, "authenticated", buyer_id)
        order_id = conn.execute(
          "SELECT public.create_ticket_order(%s, 2, %s)", (ticket_type_id, "ci-idempotency-0001")
        ).fetchone()[0]
        repeated_id = conn.execute(
          "SELECT public.create_ticket_order(%s, 2, %s)", (ticket_type_id, "ci-idempotency-0001")
        ).fetchone()[0]
        assert order_id == repeated_id
    assert conn.execute("SELECT sold_quantity FROM public.ticket_types WHERE id = %s", (ticket_type_id,)).fetchone()[0] == 2

    # Cancelling a pending order releases its inventory reservation.
    with conn.transaction():
        claim(conn, "authenticated", buyer_id)
        cancel_id = conn.execute(
          "SELECT public.create_ticket_order(%s, 2, %s)", (ticket_type_id, "ci-cancel-order-0001")
        ).fetchone()[0]
        conn.execute("SELECT public.cancel_ticket_order(%s)", (cancel_id,))
    assert conn.execute("SELECT sold_quantity FROM public.ticket_types WHERE id = %s", (ticket_type_id,)).fetchone()[0] == 2

    # Payment references are pending until trusted server verification.
    with conn.transaction():
        claim(conn, "authenticated", buyer_id)
        conn.execute(
          "SELECT public.submit_payment_reference(%s, 'Airtel Money', 'CI-REF-0001', 20000)", (order_id,)
        )
    with conn.transaction():
        claim(conn, "service_role")
        conn.execute(
          "SELECT public.verify_ticket_order_payment(%s, 'Airtel Money', 'CI-REF-0001', 20000, 'MANUAL_REFERENCE')",
          (order_id,),
        )
        # Repeated callbacks are idempotent and do not issue duplicate tickets.
        conn.execute(
          "SELECT public.verify_ticket_order_payment(%s, 'Airtel Money', 'CI-REF-0001', 20000, 'MANUAL_REFERENCE')",
          (order_id,),
        )
    assert conn.execute("SELECT status FROM public.orders WHERE id = %s", (order_id,)).fetchone()[0] == "paid"
    assert conn.execute("SELECT count(*) FROM public.tickets WHERE order_item_id IN (SELECT id FROM public.order_items WHERE order_id = %s)", (order_id,)).fetchone()[0] == 2
    assert conn.execute("SELECT count(*) FROM public.tickets WHERE order_item_id IN (SELECT id FROM public.order_items WHERE order_id = %s) AND unique_code <> qr_payload", (order_id,)).fetchone()[0] == 0
    fee_row = conn.execute("SELECT id, amount_ugx FROM public.platform_fees WHERE order_id = %s", (order_id,)).fetchone()
    assert fee_row is not None and fee_row[1] == 2000, f"Unexpected platform fee calculation: {fee_row}"

    fee_payment_id = str(uuid4())
    conn.execute("""
      INSERT INTO public.platform_fee_payments
        (id, organizer_id, amount_ugx, payment_method, payment_reference, status)
      VALUES (%s, %s, 2000, 'airtel_money', 'CI-FEE-REF-0001', 'pending')
    """, (fee_payment_id, organizer_id))
    with conn.transaction():
        claim(conn, "service_role")
        conn.execute("SELECT public.review_platform_fee_payment(%s, true, 'CI fee settlement')", (fee_payment_id,))
    assert conn.execute("SELECT status FROM public.platform_fees WHERE id = %s", (fee_row[0],)).fetchone()[0] == "paid"

    overpay_fee_id = str(uuid4())
    conn.execute("""
      INSERT INTO public.platform_fee_payments
        (id, organizer_id, amount_ugx, payment_method, payment_reference, status)
      VALUES (%s, %s, 1, 'airtel_money', 'CI-FEE-OVERPAY', 'pending')
    """, (overpay_fee_id, organizer_id))
    try:
        with conn.transaction():
            claim(conn, "service_role")
            conn.execute("SELECT public.review_platform_fee_payment(%s, true, 'should fail')", (overpay_fee_id,))
        raise AssertionError("Platform-fee overpayment was accepted")
    except errors.RaiseException as exc:
        assert "exceed assessed fees" in str(exc)
    assert conn.execute("SELECT status FROM public.platform_fee_payments WHERE id = %s", (overpay_fee_id,)).fetchone()[0] == "pending"

    ticket_code = conn.execute("SELECT unique_code FROM public.tickets WHERE order_item_id IN (SELECT id FROM public.order_items WHERE order_id = %s) LIMIT 1", (order_id,)).fetchone()[0]
    # Only the organizer owning the event can check in; each ticket is accepted once.
    with conn.transaction():
        claim(conn, "authenticated", organizer_user_id)
        conn.execute("SELECT public.check_in_ticket(%s, %s, 'qr')", (ticket_code, event_id))
    try:
        with conn.transaction():
            claim(conn, "authenticated", organizer_user_id)
            conn.execute("SELECT public.check_in_ticket(%s, %s, 'qr')", (ticket_code, event_id))
        raise AssertionError("Duplicate check-in was accepted")
    except errors.RaiseException as exc:
        assert "already used" in str(exc)

    # A customer-supplied amount cannot authorize a mismatched payment.
    with conn.transaction():
        claim(conn, "authenticated", buyer_id)
        mismatch_order = conn.execute(
          "SELECT public.create_ticket_order(%s, 1, %s)", (ticket_type_id, "ci-mismatch-order-0001")
        ).fetchone()[0]
        conn.execute(
          "SELECT public.submit_payment_reference(%s, 'Airtel Money', 'CI-REF-0002', 1)", (mismatch_order,)
        )
    try:
        with conn.transaction():
            claim(conn, "service_role")
            conn.execute(
              "SELECT public.verify_ticket_order_payment(%s, 'Airtel Money', 'CI-REF-0002', 1, 'MANUAL_REFERENCE')",
              (mismatch_order,),
            )
        raise AssertionError("Mismatched payment amount was accepted")
    except errors.RaiseException as exc:
        assert "does not match" in str(exc)

    assert conn.execute("SELECT count(*) FROM public.tickets WHERE order_item_id IN (SELECT id FROM public.order_items WHERE order_id = %s)", (mismatch_order,)).fetchone()[0] == 0
    conn.execute("UPDATE public.orders SET expires_at = now() - interval '1 minute' WHERE id = %s", (mismatch_order,))
    with conn.transaction():
        claim(conn, "service_role")
        expired_count = conn.execute("SELECT public.expire_ticket_orders()").fetchone()[0]
        assert expired_count == 1
    assert conn.execute("SELECT status FROM public.orders WHERE id = %s", (mismatch_order,)).fetchone()[0] == "expired"
    assert conn.execute("SELECT sold_quantity FROM public.ticket_types WHERE id = %s", (ticket_type_id,)).fetchone()[0] == 2

    # New-user trigger must not allow user metadata to elevate a public role.
    elevated_user_id = str(uuid4())
    conn.execute(
      "INSERT INTO auth.users (id, raw_user_meta_data) VALUES (%s, %s::jsonb)",
      (elevated_user_id, json.dumps({"role": "organizer", "display_name": "Untrusted metadata"})),
    )
    assert conn.execute("SELECT role::text FROM public.profiles WHERE id = %s", (elevated_user_id,)).fetchone()[0] == "event_goer"

print("Milky Events live-schema integration harness passed: migration, RLS, discovery, idempotent inventory, cancellation, payment verification, ticket issuance, one-time check-in and role assignment.")
