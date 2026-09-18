# Check-In Specification

Milky Events supports multiple ticket validation methods. QR is the primary method, not the only method.

## Supported methods

1. QR scan — primary fast path.
2. Ticket ID — manual unique-ticket lookup.
3. Phone number — attendee/order lookup for recovery.
4. Order reference — purchase lookup.
5. Name search — controlled manual lookup.
6. Offline validation — preloaded event ticket data with later synchronization.
7. Manual check-in — exceptional staff-assisted entry.

## Validation authority

All online check-ins are server-authoritative. A successful check-in requires:

- ticket exists;
- ticket belongs to the event being checked in;
- payment is confirmed;
- ticket is valid and not cancelled/refunded/expired;
- ticket has not already been used.

Successful validation atomically records the check-in and changes the ticket to USED.

Duplicate or invalid attempts are rejected.

## Offline mode

Offline validation is limited to event tickets explicitly synchronized to the authorized check-in device. Offline check-ins receive a local event/device record and synchronize when connectivity returns. Synchronization must reject conflicts and preserve the first valid check-in.

Offline data must not expose tickets for unrelated events.

## Security

Check-in staff operate through organizer-authorized check-in access. No public Admin role is created. Platform controls remain internal.

Never trust client-side claims of payment or ticket validity.
