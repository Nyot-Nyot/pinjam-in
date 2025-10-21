# Data Model: Borrowed Items Manager

**Date**: 2025-10-21
**Feature**: Borrowed Items Manager

This document defines the data structures for the feature, based on the entities identified in the `spec.md`.

## 1. Item Entity

This is the core entity of the application. It represents a single item that has been lent out.

| Field                 | Type          | Constraints                             | Description                                                                                                                     |
| :-------------------- | :------------ | :-------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------ |
| `id`                  | `UUID`        | Primary Key, Not Null                   | Unique identifier for the item record.                                                                                          |
| `user_id`             | `UUID`        | Foreign Key (to `auth.users`), Not Null | The user who owns this item record.                                                                                             |
| `name`                | `TEXT`        | Not Null, Min 3 chars                   | The name of the borrowed item.                                                                                                  |
| `photo_url`           | `TEXT`        | Nullable                                | URL to the item's photo in Supabase Storage.                                                                                    |
| `borrower_name`       | `TEXT`        | Not Null, Min 3 chars                   | The name of the person who borrowed the item.                                                                                   |
| `borrower_contact_id` | `TEXT`        | Nullable                                | The ID from the device's native contact list (on Android) or a manually entered phone number/contact info (on other platforms). |
| `borrow_date`         | `TIMESTAMPTZ` | Not Null, Default `NOW()`               | The date the item was lent out.                                                                                                 |
| `return_date`         | `DATE`        | Nullable                                | The expected return date.                                                                                                       |
| `status`              | `TEXT`        | Not Null, Default `'borrowed'`          | Current status. Can be `'borrowed'` or `'returned'`.                                                                            |
| `notes`               | `TEXT`        | Nullable                                | Optional notes about the item or transaction.                                                                                   |
| `created_at`          | `TIMESTAMPTZ` | Not Null, Default `NOW()`               | Timestamp of when the record was created.                                                                                       |

### State Transitions

The `status` field can transition as follows:

-   `borrowed` -> `returned` (When the user swipes to mark it as returned)

## 2. User Entity (Supabase Auth)

This entity is managed by Supabase Authentication and is referenced by the `Item` entity.

| Field   | Type   | Description                            |
| :------ | :----- | :------------------------------------- |
| `id`    | `UUID` | Primary Key, managed by Supabase.      |
| `email` | `TEXT` | User's email address.                  |
| ...     | ...    | Other fields managed by Supabase Auth. |
