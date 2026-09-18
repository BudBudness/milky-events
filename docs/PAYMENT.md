# Payment Architecture

Milky Events is powered by Pyong Recordz Ltd.

Primary collection account:
- Account: PyongCity
- Airtel Merchant Code: 6942918

## Structure
payments/checkout, orders, transactions, pyongcity, adapter, webhooks, fees, refunds, settlements, reconciliation.

The application uses a generic payment adapter boundary. Core ticketing/order logic must not depend on provider-specific implementation details.

Adapter contract:
- initialize()
- verify()
- status()
- webhook()
- refund()

Provider credentials/secrets must never be committed to the repository. Secrets belong in the deployment platform secret store.

Payment flow: Checkout -> Order -> PyongCity -> Generic Payment Adapter -> Verification -> Transaction PAID -> Ticket issuance.
Webhook handling must be idempotent and financial states auditable.
