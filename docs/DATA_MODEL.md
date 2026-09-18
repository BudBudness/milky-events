# Data Model

Core entities: User, OrganizerProfile, OrganizerPaymentMethod, Venue, Category, Event, TicketType, Order, OrderItem, Transaction, Ticket, CheckIn, PlatformFee, PlatformFeePayment, Notification.

User: id, role, name, phone, email, status, timestamps.
OrganizerProfile: id, user_id, name, description, contact, status.
OrganizerPaymentMethod: id, organizer_id, method, provider, account_identifier, account_name, verification_status, active, timestamps.
Venue: id, name, address, area, latitude, longitude.
Category: id, name, description, active.
Event: id, organizer_id, category_id, venue_id, title, description, poster_url, starts_at, ends_at, status, created_at, published_at.
TicketType: id, event_id, name, price_ugx, quantity, sold_quantity, status.
Order: id, user_id, event_id, total_amount_ugx, service_fee_ugx, status, created_at, paid_at.
OrderItem: id, order_id, ticket_type_id, quantity, unit_price_ugx, subtotal_ugx.
Transaction: id, order_id, provider, provider_reference, amount_ugx, currency, status, created_at, confirmed_at.
Ticket: id, order_item_id, event_id, user_id, ticket_type_id, unique_code, qr_payload, status, issued_at, checked_in_at.
CheckIn: id, ticket_id, event_id, checked_by, checked_at, result.
PlatformFee: id, organizer_id, event_id, order_id, amount_ugx, status, created_at.
PlatformFeePayment: id, organizer_id, amount_ugx, payment_method, payment_reference, status, submitted_at, verified_at.
Notification: id, user_id, event_id, type, status, sent_at.

Currency is UGX. Store money as integer Uganda shillings; never use floating-point money values.

There is no Milky Events payout/settlement entity in V1 because organizer ticket revenue is collected directly by organizers.
