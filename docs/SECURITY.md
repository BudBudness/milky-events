# Security Baseline

- Enforce role-based access for Event-goer and Organizer.
- Organizers may access only their own events, ticket types, attendees and permitted reports.
- Event-goers may access only their own orders and tickets.
- Payment callbacks are verified and idempotent.
- QR ticket validation is server-side.
- Never expose merchant credentials or payment secrets in frontend code.
- Audit payment, refund, settlement, event approval and ticket check-in actions.
- Validate dates, quantities, prices, ownership and state transitions server-side.
