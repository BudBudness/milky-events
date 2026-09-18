# Architecture

Milky Events is a Mbarara-first event discovery and digital ticketing platform powered by Pyong Recordz Ltd.

## Public roles
1. Event-goer
2. Organizer

Platform operations are internal and are not exposed as a public role.

## Core flow
Organizer creates event -> event is approved/published -> event-goer discovers event -> selects ticket -> payment -> verified transaction -> QR ticket -> organizer check-in -> settlement.

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
