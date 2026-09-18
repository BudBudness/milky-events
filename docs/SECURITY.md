# Security Baseline

- Enforce access control for Event-goer and Organizer.
- Internal platform operations are private and are not a public user role.
- Organizers may access only their own events, ticket types, attendees and permitted reports.
- Event-goers may access only their own orders and tickets.
- Payment callbacks/provider responses are verified and idempotent where supported.
- Manual payment-reference verification requires an authorized internal action or explicitly configured organizer verification flow.
- QR ticket validation is server-side.
- Offline check-in devices receive only explicitly synchronized tickets for the assigned event.
- Never expose organizer payment credentials or provider secrets in frontend code.
- Do not expose unrelated organizers' payment methods or financial records.
- Audit ticket payments, payment verification, platform-fee payments, refunds, event approval/rejection, organizer payment-method verification and ticket check-in.
- Validate dates, quantities, prices, ownership, amounts and state transitions server-side.
- Use integer UGX values for all money.
- Use idempotency controls for checkout, payment confirmation and ticket issuance.
- Platform-fee payment records are immutable/auditable after verification.
- Provider references must be protected against duplicate use.
- Do not allow a client to select another organizer's payment method.
- Do not allow an unverified/inactive organizer payment method to be presented as a valid checkout destination.
