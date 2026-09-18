# Workflows

## Event lifecycle

DRAFT -> PENDING_APPROVAL -> PUBLISHED -> COMPLETED

DRAFT/PENDING_APPROVAL -> REJECTED

PUBLISHED -> CANCELLED

Only internal platform controls may approve, reject, suspend, or cancel an event on platform policy grounds.

## Order lifecycle

CREATED -> PAYMENT_PENDING -> PAID -> TICKET_ISSUED

PAYMENT_PENDING -> FAILED or EXPIRED

## Customer payment verification

1. Customer selects ticket type and quantity.
2. Server creates the order and reserves/validates inventory.
3. Event payment instructions for the organizer's active verified payment method are shown.
4. Customer pays the organizer directly.
5. Customer submits the provider transaction/reference when required.
6. Milky Events verifies the payment through the configured direct provider module, or through authorized reference verification where automated verification is unavailable.
7. Server validates amount, order, provider, reference and current order state.
8. Transaction becomes PAID.
9. Ticket issuance runs idempotently.
10. Order becomes TICKET_ISSUED.

No ticket may be issued solely from client-side payment confirmation.

## Organizer payment-method workflow

1. Organizer adds a payment method.
2. Required account/merchant details are validated.
3. Method enters verification state.
4. Internal verification or supported provider verification confirms ownership/details.
5. Method becomes ACTIVE.
6. Organizer assigns the method to eligible events.
7. Disabled/unverified methods cannot receive new checkout instructions.

## Platform-fee workflow

1. Paid ticket/order creates a PlatformFee according to the active PlatformFeeRule.
2. Fee is attached to the organizer and underlying event/order/ticket.
3. Organizer dashboard shows accumulated and outstanding fees.
4. Organizer pays Milky Events separately.
5. Organizer submits payment reference and amount.
6. Record becomes PENDING.
7. Authorized internal platform control verifies or rejects the payment.
8. VERIFIED payment reduces outstanding balance.
9. Rejected payment does not reduce balance.
10. Historical records remain auditable and are never silently overwritten.

## Refund/cancellation workflow

1. Organizer/platform action changes the relevant order/ticket state.
2. Milky Events records the cancellation/refund state.
3. Actual customer money movement is handled by the organizer/payment provider because Milky Events does not custody ticket revenue.
4. Any platform-fee reversal is calculated from the fee rule attached to the original fee.
5. Reversal is recorded as a separate auditable financial entry.

## Check-in workflow

Online:
1. Staff scans QR or searches by Ticket ID, phone, order reference, or name.
2. Server validates ticket existence, event ownership, payment status, ticket status and expiry.
3. Valid ticket changes atomically VALID -> USED.
4. Duplicate attempts are rejected.

Offline:
1. Authorized check-in device synchronizes eligible tickets for the specific event.
2. Device validates only synchronized tickets for that event.
3. Successful offline check-ins are stored locally.
4. Sync reconciles with the server.
5. First valid check-in wins; conflicts do not restore a used ticket.

## Purchase invariants

- Never issue a ticket from client-side payment success alone.
- Payment must be verified.
- Ticket issuance is idempotent.
- Repeated callbacks/references cannot create duplicate tickets.
- Ticket quantity and amount are validated server-side.
- A ticket can be checked in only once.
- A ticket must belong to the event being checked in.
- Inventory cannot be oversold.
