# Data Model

Core entities:
User, OrganizerProfile, OrganizerPaymentMethod, Venue, Category, Event, TicketType, Order, OrderItem, Transaction, Ticket, CheckIn, PlatformFee, PlatformFeePayment, Notification.

## Identity and organization

**User:** id, role, name, phone, email, status, timestamps.

**OrganizerProfile:** id, user_id, name, description, contact, status.

**OrganizerPaymentMethod:** id, organizer_id, method, provider, account_identifier, account_name, verification_status, active, timestamps.

## Discovery and events

**Venue:** id, name, address, area, latitude, longitude.

**Category:** id, name, description, active.

**Event:** id, organizer_id, category_id, venue_id, title, description, poster_url, starts_at, ends_at, status, created_at, published_at.

**TicketType:** id, event_id, name, price_ugx, quantity, sold_quantity, status.

## Orders and ticket payments

**Order:** id, user_id, event_id, total_amount_ugx, status, created_at, paid_at.

Do not add a customer service fee unless an explicit V1 business rule is introduced. Organizer-owned collection does not require Milky Events to add a checkout service charge.

**OrderItem:** id, order_id, ticket_type_id, quantity, unit_price_ugx, subtotal_ugx.

**Transaction:** id, order_id, provider, provider_reference, amount_ugx, currency, status, verification_source, created_at, confirmed_at.

Transaction verification_source values:
- PROVIDER
- MANUAL_REFERENCE

## Tickets and check-in

**Ticket:** id, order_item_id, event_id, user_id, ticket_type_id, unique_code, qr_payload, status, issued_at, checked_in_at.

**CheckIn:** id, ticket_id, event_id, checked_by, checked_at, result, method, device_id, sync_status.

## Platform fees

**PlatformFeeRule:** id, name, percentage_bps, fixed_amount_ugx, basis, free_event_policy, refund_policy, payable_rule, active, effective_from, effective_to.

Use integer basis points for percentage values. Never store percentage calculations as floating-point values.

**PlatformFee:** id, organizer_id, event_id, order_id, ticket_id, amount_ugx, status, fee_rule_id, created_at, reversed_at.

**PlatformFeePayment:** id, organizer_id, amount_ugx, payment_method, payment_reference, status, submitted_at, verified_at, verified_by.

PlatformFeePayment status:
- PENDING
- VERIFIED
- REJECTED

## Notifications

**Notification:** id, user_id, event_id, type, status, sent_at.

## Invariants

- Currency is UGX.
- Store money as integer Uganda shillings.
- Never use floating-point money.
- Historical financial records are append-only/auditable.
- Platform fee calculations reference the fee rule used at calculation time.
- There is no Milky Events organizer payout/settlement entity in V1.
