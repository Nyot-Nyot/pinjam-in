# REST Contracts (high level)

Note: Supabase provides Postgres + storage, so many operations will use the
Postgres REST endpoints (PostgREST) or client libraries. These contracts are
high-level actions the client must perform.

## Auth

-   POST /auth/v1/signup (email) — create account
-   POST /auth/v1/token (email login) — obtain session token
-   POST /auth/v1/logout — invalidate session

## Borrowed Items

-   GET /items?user_id={user} — list items for user (supports filters: status, q=item_name)
-   POST /items — create item (body: item_name, borrower_name, contact_phone?, return_date?, notes?, photo_url?)
-   GET /items/{id} — get item details
-   PATCH /items/{id} — update item
-   DELETE /items/{id} — delete item
-   POST /items/{id}/mark_returned — mark item returned (sets status and returned_at)

## Photos / Media

-   POST /storage/v1/object/{bucket} — upload photo, returns URL
-   GET /storage/v1/object/{bucket}/{path} — download

## Contacts

-   GET /contacts?user_id={user} — list saved contacts
-   POST /contacts — save contact reference (with consent)
-   DELETE /contacts/{id} — delete contact reference

**Note**: Exact endpoints depend on Supabase client's usage; this contract is
meant to guide client implementation and tests.
