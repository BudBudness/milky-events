# Milky Events — Base44 V1 Master Build Prompt

Build the application defined by this repository. Treat the repository documentation as the product contract. Do not redesign the product, broaden scope, invent roles, or introduce unnecessary architecture.

## Product

Milky Events is an Mbarara-first event discovery and digital ticketing platform powered by Pyong Recordz Ltd.

Public roles:
1. Event-goer
2. Organizer

There is no public Admin role. Platform operations are private/internal.

Positioning: Everything happening in Mbarara.

## Discovery

Home:
- Trending
- Near You
- Tonight
- This Weekend
- Upcoming
- Free Events
- Popular Events
- Categories

Primary navigation:
- Home
- Explore
- Tickets
- Create Event
- Profile

Create Event is available to organizers.

Filters:
- Date
- Category
- Location
- Price
- Free/Paid

Free/Paid is a filter, not a category.

Seed exactly these 12 categories:
1. Music
2. Nightlife
3. Sports
4. Comedy
5. Arts & Culture
6. Business
7. Education
8. Community
9. Faith
10. Family & Lifestyle
11. Markets & Shopping
12. Private & Social

## Event

Organizer creates:
- title
- poster
- category
- description
- date
- start/end time
- venue
- location
- map/directions
- ticket types
- ticket quantities/prices
- terms
- contact information

Event lifecycle:
DRAFT -> PENDING_APPROVAL -> PUBLISHED -> COMPLETED

DRAFT/PENDING_APPROVAL -> REJECTED

PUBLISHED -> CANCELLED

Internal platform controls approve/reject/suspend/cancel events. Do not expose those controls as a public Admin account.

## Ticketing

Ticket types may be Early Bird, Regular, VIP, VVIP or organizer-created.

Each ticket has:
- unique ticket ID/code
- order ID
- event ID
- ticket type
- customer
- issued timestamp
- QR payload
- status

Ticket states:
- VALID
- USED
- CANCELLED
- REFUNDED
- EXPIRED

Ticket issuance is server-authoritative and idempotent.

Never issue a ticket merely because the frontend reports payment success.

## Payment architecture

Use organizer-owned collection.

Customer -> Order -> Organizer payment method -> Payment verification -> Ticket

Milky Events does not custody organizer ticket revenue.

Do not build:
- PyongCity collection
- organizer payout/settlement
- generic payment adapter

Use direct provider modules under:
payments/providers/mtn/
payments/providers/airtel/
payments/providers/bank/

Add other direct providers only when actually implemented.

Organizer payment methods contain:
- method/provider
- account/merchant identifier
- account name
- verification status
- active/inactive status
- event assignment

Only verified active methods can be used by published paid events.

## Customer payment verification

Support two modes:

1. Direct provider verification where a configured provider API/module is available.
2. Manual transaction-reference verification as the V1 fallback where automated verification is unavailable.

For manual/reference verification, the customer submits the provider transaction/reference and an authorized verifier confirms it.

Validate:
- order
- event
- provider/method
- reference
- amount
- order state

Protect against duplicate provider references.

Order lifecycle:
CREATED -> PAYMENT_PENDING -> PAID -> TICKET_ISSUED

PAYMENT_PENDING -> FAILED or EXPIRED

## Platform fees

Platform fees are separate from ticket revenue.

Do not hard-code an arbitrary percentage.

Implement a PlatformFeeRule with:
- percentage in integer basis points
- fixed UGX amount
- basis: per ticket or per order
- free-event treatment
- refund/cancellation treatment
- payable timing
- effective dates
- active/inactive state

Every PlatformFee must record the rule used.

Organizer fee ledger:
- accumulated fees
- payments submitted
- verified payments
- outstanding balance
- payment history
- payment references
- status

Organizer pays platform fees separately to:

Airtel Money: 0700709940
Name: EDDIE BYAMUGISHA

Stanbic Bank: 9030017150749
Name: EDDIE BYAMUGISHA

These destinations are for Milky Events platform fees only.

Platform-fee payment states:
PENDING
VERIFIED
REJECTED

Verification is idempotent and auditable. Verified historical records must not be silently mutated.

## Refunds

Milky Events records cancellation/refund states but does not custody or move organizer ticket revenue.

The organizer/payment provider handles the actual customer refund.

Any platform-fee reversal is recorded separately and references the original fee rule/fee.

## Check-in

Primary:
- QR scan

Additional:
- Ticket ID
- Phone number
- Order reference
- Name search
- Manual staff-assisted check-in
- Offline synchronized validation

Online validation must confirm:
- ticket exists
- correct event
- payment confirmed
- not cancelled/refunded/expired
- not already used

Successful check-in atomically changes:
VALID -> USED

Offline devices may only hold explicitly synchronized tickets for the assigned event. Sync preserves the first valid check-in.

## Notifications

Implement deterministic notifications for:
- event submission
- approval/rejection
- order/payment state
- ticket issuance
- event cancellation
- check-in where appropriate
- platform-fee submission
- fee verification/rejection
- fee reminders

## Data integrity

Use integer UGX. Never use floating-point money.

Server-side validation is mandatory for:
- prices
- quantities
- inventory
- amounts
- ownership
- dates
- state transitions
- payment references

Prevent overselling.

Payment callbacks and ticket issuance must be idempotent.

Do not expose unrelated organizer data.

## Architecture constraints

Use deterministic modules, workflows, policies, permissions and state machines as the authoritative execution path.

Do not introduce autonomous agents into payment, ticketing, approval, authorization, financial or check-in execution.

Do not add unnecessary abstraction layers.

Do not create:
- payments/adapter
- payments/pyongcity
- payments/settlements

## Internal platform controls

Private platform controls must support:
- event review/approve/reject with reason
- organizer verification
- payment-method verification
- event suspension/cancellation
- category management
- platform-fee rule management
- platform-fee payment verification/rejection
- audit logs

These are internal controls, not a public role.

## UI requirements

Mobile-first, fast, clean and suitable for Mbarara users.

Event page must show:
- poster
- event name
- category
- description
- date
- start/end time
- venue/location
- directions
- organizer
- ticket types/prices
- remaining quantity
- terms
- contact
- GET TICKET CTA

Organizer dashboard:
- Dashboard
- My Events
- Create Event
- Ticket Types
- Sales
- Attendees
- Check-in
- Platform Fees/Billing

Do not create a Settlements screen for organizer ticket revenue.

## Delivery

Build the smallest complete V1 that satisfies this contract.

Prioritize working end-to-end flows:
1. Authentication
2. Organizer profile
3. Organizer payment method
4. Event creation
5. Internal approval
6. Public discovery
7. Checkout/order
8. Payment verification
9. Idempotent ticket issuance
10. Ticket display/QR
11. Check-in
12. Organizer sales/attendees
13. Platform-fee ledger
14. Platform-fee payment submission and internal verification
15. Notifications
16. Audit trail

Do not spend implementation effort on speculative features.

Before considering V1 complete, verify the critical invariants with deterministic tests.
