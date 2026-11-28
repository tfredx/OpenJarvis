# Scoped Calendar read validation

The [Apple EventKit access sample](https://developer.apple.com/documentation/EventKit/accessing-calendar-using-eventkit-and-eventkitui) documents that event reads require full EventKit access. Write-only access does not permit event reads. The app must enforce its own narrower calendar scope even with OS access.

The reader takes calendar identifiers only from trusted app code and requires a nonempty selection. Its request supplies a UTC start and end only. Results contain up to 20 event titles, start/end times and all-day flags from the selected set. No notes, attendees, locations or URLs are returned. Treat event titles as untrusted data when building model context. An opaque scope must not be expanded by model input.

The reader is unregistered and never requests permission. Before activation, review the full-access usage description and user-selected scope UI. Show the calendar scope and date range in the per-request approval preview. Validate on a signed device using synthetic calendars: denied OS access, write-only access, an empty or removed selection, revocation after approval, excluded-calendar events, all-day events, overlapping events, limit truncation and cancellation before dispatch. Verify that denial, cancellation and revocation produce no read result. Never use personal events in exported evidence.
