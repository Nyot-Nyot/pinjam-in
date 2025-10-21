# Data Model: Borrowed items manager

## Entities

### BorrowedItem

-   id: uuid (primary)
-   user_id: uuid (owner)
-   item_name: string (required, max 255)
-   borrower_name: string (required, max 255)
-   contact_id: string (optional) — platform contact id or stored contact reference
-   contact_phone: string (optional) — stored only with consent
-   photo_url: string (optional) — URL to Supabase Storage object
-   return_date: date (optional)
-   notes: text (optional)
-   status: enum (borrowed, returned)
-   created_at: timestamptz
-   returned_at: timestamptz (optional)

Validation rules:

-   item_name and borrower_name required
-   phone must match E.164 format if stored

### User (Supabase Auth)

-   id: uuid
-   email: string
-   created_at: timestamptz

### Contact (optional local reference)

-   id: uuid
-   platform_contact_id: string (Android reference) optional
-   display_name: string
-   phone: string (stored only with consent)
-   owner_user_id: uuid

## Relationships

-   BorrowedItem.user_id -> User.id
-   BorrowedItem.contact_id -> Contact.id (optional)

## Indexes & Performance

-   Index on user_id for fast per-user queries
-   Index on status and item_name for filtering/search
-   Consider materialized view or cached aggregates for statistics

**End of data model**
