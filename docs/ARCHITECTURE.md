# Architecture

Milky Events is a Mbarara-first event discovery and digital ticketing platform powered by Pyong Recordz Ltd.

## Public roles
1. Event-goer
2. Organizer

Platform operations are internal and are not exposed as a public role.

## Core flow
Organizer creates event -> event is approved/published -> event-goer discovers event -> selects ticket -> pays through the organizer's configured payment method -> payment is verified -> ticket is issued -> organizer check-in.

Organizer ticket revenue does not pass through Milky Events. Milky Events calculates platform fees separately, and the organizer pays accumulated fees to Milky Events.

## Folder-over-agents
Deterministic modules, workflows, policies, validation, permissions, and state transitions own application behavior. AI/agents are not required for core execution and must not make payment, ticket, approval, or authorization decisions.

## Major modules
- auth
- events
- categories
- venues
- organizers
- discovery
- tickets
- attendees
- payments
- notifications
- policies
- workflows
- admin (internal platform controls only)

## Payments
Payment provider implementations are direct provider modules. No generic adapter layer is required for V1. No PyongCity payment dependency is required.
