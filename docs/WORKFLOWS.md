# Workflows

## Event lifecycle
DRAFT -> PENDING_APPROVAL -> PUBLISHED -> COMPLETED
DRAFT/PENDING_APPROVAL -> REJECTED
PUBLISHED -> CANCELLED

## Order lifecycle
CREATED -> PAYMENT_PENDING -> PAID -> TICKET_ISSUED
PAYMENT_PENDING -> FAILED or EXPIRED

## Ticket lifecycle
VALID -> USED
VALID -> CANCELLED
VALID -> REFUNDED

## Purchase invariants
- Never issue a ticket from client-side payment success alone.
- Payment must be verified by the payment integration.
- Ticket issuance must be idempotent.
- Repeated provider callbacks must not create duplicate tickets.
- A ticket can be checked in only once.
- A ticket must belong to the event being checked in.
- Paid order amount and ticket quantities must be validated server-side.
