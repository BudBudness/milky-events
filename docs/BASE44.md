# Base44 Implementation Contract

Implement the product from this repository specification rather than redesigning it.

Do not introduce autonomous agents, agentic workflows, additional public roles, unnecessary abstractions, or unnecessary features.

Preserve Mbarara-first scope, Event-goer + Organizer roles, 12 categories, deterministic workflows/state machines, organizer-owned payment collection, direct provider modules without a generic payment adapter, QR ticket issuance, multi-method check-in, idempotent payment handling, and internal platform controls without an Admin user role.

## Payment requirements

Customers pay organizers through organizer-configured payment methods. Milky Events does not custody organizer ticket revenue.

Organizers owe Milky Events accumulated platform fees. Provide an organizer fee ledger showing:
- current amount due
- accumulated fees
- payments submitted
- verified payments
- outstanding balance
- payment history

Organizers pay platform fees separately to:

- Airtel Money: 0700709940
- Stanbic Bank: 9030017150749
- Account name: EDDIE BYAMUGISHA

These accounts are for Milky Events platform fees only.

Allow organizers to submit a payment reference for verification. Do not build PyongCity collection or a generic payment adapter for V1.

Build the smallest complete V1 satisfying the documented workflows and data model.
