# Payment Architecture

Milky Events uses organizer-owned ticket collection.

## Customer ticket payments

Customers pay the organizer through a payment method configured for the event. Milky Events does not custody organizer ticket revenue.

Supported/configurable methods:
- MTN Mobile Money
- Airtel Money
- Bank account
- Additional direct provider modules when implemented

Provider implementations live directly under `payments/providers/`. There is no generic payment adapter.

### Verification

A paid ticket is issued only after Milky Events has a verified payment record.

Verification modes:
1. **Provider verification** — used where a direct provider integration/API is available and configured.
2. **Reference verification** — V1 fallback where automated provider verification is unavailable. The customer submits the provider transaction/reference, and an authorized platform operator or organizer verifies it according to the configured workflow.

The system must never treat a client-side "payment successful" screen as proof of payment.

Required transaction fields include:
- order_id
- provider/method
- provider_reference
- amount_ugx
- status
- created_at
- confirmed_at
- verification_source

Duplicate provider references must not create duplicate payments or tickets.

## Organizer payment methods

Organizers can add/configure:
- provider/method
- account or merchant identifier
- account name
- verification status
- active/inactive status
- events using the method

A payment method must be active and verified before it can be used for a published paid event.

Provider credentials/secrets must never be committed or exposed in frontend code.

## Milky Events platform fees

Platform fees are separate from customer ticket payments. Milky Events never receives organizer ticket revenue and never creates an organizer payout/settlement in V1.

### Fee rule

V1 supports a configurable platform-fee rule managed by internal platform controls. The fee rule is represented explicitly and must not be hard-coded into checkout logic.

The fee rule must define:
- percentage and/or fixed amount
- whether it applies per ticket or per order
- treatment of free events
- treatment of cancelled/refunded tickets
- when a fee becomes payable

If no active fee rule exists, the system must not silently calculate zero fees.

### Fee ledger

For each organizer, show:
- accumulated fees
- payments submitted
- verified payments
- outstanding balance
- payment history
- payment reference
- payment status
- submitted_at
- verified_at

Organizer fee payment states:
- PENDING
- VERIFIED
- REJECTED

A submitted payment reference must be unique within the platform payment ledger. Verification must be idempotent.

### Fee payment destination

Organizers pay accumulated Milky Events platform fees separately:

**Airtel Money**
- Number: 0700709940
- Name: EDDIE BYAMUGISHA

**Stanbic Bank**
- Account: 9030017150749
- Name: EDDIE BYAMUGISHA

These accounts are for Milky Events platform-fee payments only, not customer ticket payments.

## Refunds and cancellations

Because organizer ticket revenue is collected directly by the organizer, Milky Events does not initiate or custody the refund funds in V1.

Milky Events records the ticket/order refund or cancellation state and the related audit information. The organizer/provider arrangement determines the actual money movement.

Any platform fee reversal must be calculated by the active fee rule and recorded explicitly; never mutate historical financial records silently.

## Financial integrity

- Store money as integer UGX.
- Validate amounts server-side.
- Use idempotency keys for checkout/payment confirmation.
- Make provider callbacks idempotent.
- Keep financial records auditable.
- Never issue duplicate tickets.
- Never expose unrelated organizers' financial data.
