# Security Baseline

- Enforce role-based access for Event-goer and Organizer.
- Organizers may access only their own events, ticket types, attendees and permitted reports.
- Event-goers may access only their own orders and tickets.
- Payment callbacks/provider responses are verified and idempotent where supported.
- QR ticket validation is server-side.
- Never expose organizer payment credentials or provider secrets in frontend code.
- Audit ticket payments, platform-fee payments, refunds, event approval and ticket check-in actions.
- Validate dates, quantities, prices, ownership and state transitions server-side.
- Do not expose unrelated organizers' payment methods or financial records.
- Platform-fee payment records must be immutable/auditable after verification.
