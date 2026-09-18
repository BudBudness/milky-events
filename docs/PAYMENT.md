# Payment Architecture

Milky Events uses organizer-owned payment collection.

## Customer ticket payments
Customers pay the organizer through the payment method configured for the event. Milky Events does not custody organizer ticket revenue.

Supported/configurable payment methods can include:
- MTN Mobile Money
- Airtel Money
- Bank account
- Additional providers when implemented

Provider implementations live directly under `payments/providers/`. No generic adapter is required for V1.

## Payment flow
Checkout -> Order -> Organizer's configured payment method -> Payment verification -> Transaction PAID -> Ticket issuance.

Ticket issuance must never depend only on client-side payment success. Payment must be verified and ticket issuance must be idempotent.

Core payment states:
- PAYMENT_PENDING
- PAYMENT_PAID
- PAYMENT_FAILED
- PAYMENT_EXPIRED

## Organizer payment methods
Organizers can add/configure payment methods with:
- method/provider
- account or merchant identifier
- account name
- verification status
- active/inactive status
- events using the method

Secrets and provider credentials must never be committed to the repository or exposed in frontend code.

## Milky Events platform fees
Milky Events calculates platform fees owed by each organizer independently of customer ticket payments.

Organizers pay accumulated platform fees to:

**Airtel Money**
- Number: 0700709940
- Name: EDDIE BYAMUGISHA

**Stanbic Bank**
- Account: 9030017150749
- Name: EDDIE BYAMUGISHA

These accounts are for platform-fee payments only.

Organizer fee payments must support:
- amount due
- payment reference
- submitted_at
- verification status
- verified_at
- payment history
- outstanding balance

No organizer ticket revenue is represented as a Milky Events payout or settlement in V1.

## Financial integrity
- Store money as integer UGX.
- Validate amounts server-side.
- Make provider callbacks idempotent.
- Keep financial records auditable.
- Never issue duplicate tickets for repeated callbacks.
- Refund behavior depends on the payment provider and organizer arrangement.
