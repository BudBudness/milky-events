# Base44 Implementation Contract

Implement the product from this repository specification rather than redesigning it.

Do not introduce autonomous agents, agentic workflows, additional public roles, unnecessary abstractions, or unnecessary features.

Preserve:
- Mbarara-first scope.
- Event-goer + Organizer public roles only.
- 12 categories.
- Deterministic modules, workflows, policies, validation and state machines.
- Organizer-owned payment collection.
- Direct provider modules without a generic payment adapter.
- QR ticket issuance and multi-method check-in.
- Idempotent payment handling.
- Private internal platform controls without a public Admin role.
- No PyongCity dependency.
- No organizer payout/settlement flow.

## Customer payments

Customers pay organizers through an organizer payment method assigned to the event.

Payment verification must support:
1. Direct provider verification where a provider module/API is configured.
2. Manual transaction-reference verification as the V1 fallback where automated provider verification is unavailable.

Never issue a ticket from client-side payment success alone.

## Organizer payment methods

Implement:
- add/edit/deactivate organizer payment methods
- provider/method
- merchant/account identifier
- account name
- verification status
- active status
- event assignment

Only verified active methods can be used by published paid events.

## Platform fees

Implement an explicit platform fee rule entity/configuration. Do not hard-code an arbitrary fee rate.

A fee rule must support:
- percentage in integer basis points
- fixed UGX amount
- basis: per ticket or per order
- free-event treatment
- refund/cancellation treatment
- payable timing
- effective dates
- active/inactive state

Every PlatformFee stores the rule used to calculate it.

Organizer dashboard must show:
- accumulated fees
- payments submitted
- verified payments
- outstanding balance
- payment history
- references
- status

Organizer platform-fee payment destinations:
- Airtel Money: 0700709940
- Stanbic Bank: 9030017150749
- Account name: EDDIE BYAMUGISHA

These are platform-fee destinations only.

## Internal platform controls

Private controls must support:
- event review/approve/reject with reason
- organizer/payment-method verification
- event suspension/cancellation
- category management
- fee-rule management
- platform-fee payment verification/rejection
- audit log access

Do not expose these controls as a public Admin role.

## Refunds

Milky Events records ticket/order cancellation/refund state. The organizer/payment provider handles actual money movement because ticket revenue never enters Milky Events custody.

Any platform-fee reversal must be a separate auditable entry.

## Notifications

Implement deterministic notifications for:
- event submission/approval/rejection
- order/payment status
- ticket issuance
- event cancellation
- check-in result where appropriate
- platform-fee submission/verification/rejection
- fee reminders

## V1 quality requirements

- Server-side validation for all money, quantity, ownership and state transitions.
- Integer UGX only.
- Idempotent payment callbacks and ticket issuance.
- No duplicate tickets.
- No overselling.
- One-time check-in.
- Event-scoped offline check-in.
- No unrelated organizer data exposure.
- Responsive mobile-first UI suitable for Mbarara users.
- Seed the 12 categories.
- Keep the implementation small and deterministic.
