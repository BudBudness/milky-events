# Data Model

Core entities: User, OrganizerProfile, Venue, Category, Event, TicketType, Order, OrderItem, Transaction, Ticket, CheckIn, Settlement, Notification.

User: id, role, name, phone, email, status, timestamps.
OrganizerProfile: id, user_id, name, description, contact, status.
Venue: id, name, address, area, latitude, longitude.
Category: id, name, description, active.
Event: id, organizer_id, category_id, venue_id, title, description, poster_url, starts_at, ends_at, status, created_at, published_at.
TicketType: id, event_id, name, price_ugx, quantity, sold_quantity, status.
Order: id, user_id, event_id, total_amount_ugx, service_fee_ugx, status, created_at, paid_at.
OrderItem: id, order_id, ticket_type_id, quantity, unit_price_ugx, subtotal_ugx.
Transaction: id, order_id, provider, provider_reference, amount_ugx, currency, status, created_at, confirmed_at.
Ticket: id, order_item_id, event_id, user_id, ticket_type_id, unique_code, qr_payload, status, issued_at, checked_in_at.
CheckIn: id, ticket_id, event_id, checked_by, checked_at, result.
Settlement: id, event_id, gross_ugx, fees_ugx, net_ugx, status, eligible_at, settled_at.
Notification: id, user_id, event_id, type, status, sent_at.

Currency is UGX. Store money as integer Uganda shillings; never use floating-point money values.
