# Research: Borrowed items manager

## Decision: Backend & Storage

-   Decision: Use Supabase (Postgres + Supabase Storage) on free tier for structured
    data and photo storage.
-   Rationale: Supabase provides a managed Postgres DB, auth, and object storage in
    a single service, which speeds development and matches the user's stated
    preference.
-   Alternatives considered:
    -   Firebase: Mature mobile backend, but user specified Supabase.
    -   Custom backend: Higher maintenance and out of scope for initial delivery.

## Decision: Authentication

-   Decision: Email-only account-based authentication via Supabase Auth.
-   Rationale: User requested email-only auth; this supports multi-device sync and
    minimal UX friction.
-   Alternatives:
    -   OAuth / SSO: Unnecessary for MVP and increases external dependencies.

## Decision: Photo storage

-   Decision: Photos will be uploaded to Supabase Storage and referenced by URL in
    the Postgres records.
-   Rationale: Keeps media separate from structured data and fits the user's
    request for cloud media storage.
-   Alternatives:
    -   Store photos inline (not recommended due to DB bloat).

## Decision: Contact handling

-   Decision: Use Android contact picker integration; on Android store phone and
    display name only with explicit consent. On non-Android platforms, use a
    phone-number input field.
-   Rationale: Matches the user's requested platform-specific behavior and limits
    PII storage.
-   Alternatives:
    -   Always use free-text borrower name (simplest) — but loses pick-from-contacts
        convenience on Android.

## Decision: Offline resilience & syncing

-   Decision: Implement offline-first local cache (SQFlite or local storage) with
    background sync to Supabase when the network is available. Conflict strategy:
    last-writer-wins for MVP with potential manual merge UI for conflicts.
-   Rationale: Supabase free tier and mobile networks require handling offline
    usage. Local-first improves perceived performance and reliability.
-   Alternatives:
    -   Only online mode (simpler) — poor UX when offline.
    -   Advanced CRDT or operational transform syncing (too large scope for MVP).

## Decision: State management

-   Decision (recommended): Use Riverpod for predictable state management and
    testability.
-   Rationale: Riverpod has strong test support, is popular in Flutter ecosystem,
    and works well with async data streams from Supabase.
-   Alternatives:
    -   Provider: simpler but less testable for complex flows.
    -   Bloc: more boilerplate, can be used if team prefers.

## Decision: Image handling

-   Decision: Compress images on-device before upload; use thumbnail variants in
    list views to reduce memory and network usage.
-   Rationale: Improves perceived performance and reduces Supabase storage usage.

## Research Tasks (Phase 0)

-   R001: Verify Supabase free-tier storage quotas and request limits (link to
    docs, expected quotas).
-   R002: Evaluate Android contact picker package compatibility with current
    Flutter SDK (e.g., `contacts_service`, `flutter_contact_picker`).
-   R003: Prototype offline cache + sync with Supabase (SQFlite + background sync).
-   R004: Confirm Riverpod integration patterns for testing and async streams.

**End of research**
