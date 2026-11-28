# ADR-0010 — Native device capability dispatch boundary

Status: accepted for an inert, permission-neutral interface; no system adapters are enabled.

## Decision

Represent possible device operations with a closed enum of fixed capability IDs. Register adapters only in trusted app code, reject duplicate registrations and unknown model-supplied IDs, and pass bounded typed requests to a matching adapter. Require the independent `ToolAuthorization` policy to allow the exact fixed ID, then request fresh human approval for every invocation. Default authorization and approval deny. Bound request and result sizes and reject embedded NUL input.

Concrete adapters must validate capability-specific arguments, apply platform authorization, and use only the minimum required iOS permission. App-level human approval does not replace the OS permission prompt. No capability may write arbitrary files, run shell commands, access the network, schedule background work or introduce a generic resource parameter. Approval state is not persisted as an implicit reusable grant.

## Scope and gates

This increment provides only the dispatcher seam and fake-adapter tests. It registers no Calendar, Contacts, Photos, Reminders or Location provider and adds no usage-description key, entitlement or permission request. The SwiftUI app does not call this dispatcher yet. Before enabling a provider, add a separate reviewed change for its specific permission, user-facing rationale, argument validation, denial/revocation behavior and native simulator/device tests. No physical-device permission behavior is claimed.

Regression tests cover default deny, unknown/unregistered IDs, independent authorization, explicit approval/decline, repeat approval, duplicate registration, malformed input and oversized output. The tests are authored on `feat/ios-native-capability-interfaces`; Swift/Xcode CI remains required.
