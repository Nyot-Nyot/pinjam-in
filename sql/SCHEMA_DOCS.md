# Supabase Schema: Borrowed Items Manager

**Date**: 2025-12-02 (Updated for admin role support)
**Feature**: Borrowed Items Manager with Admin Role

This file documents the SQL schema for the tables and policies in the Supabase PostgreSQL database.

## Database Structure

### 1. `profiles` Table

This table stores user metadata and role information.

| Column       | Type        | Constraints                                                                     | Description                  |
| ------------ | ----------- | ------------------------------------------------------------------------------- | ---------------------------- |
| `id`         | UUID        | PRIMARY KEY, REFERENCES auth.users(id)                                          | User ID (from Supabase Auth) |
| `full_name`  | TEXT        | nullable                                                                        | User's full name             |
| `role`       | TEXT        | NOT NULL, DEFAULT 'user', CHECK (role IN ('user','admin'))                      | User role                    |
| `status`     | TEXT        | NOT NULL, DEFAULT 'active', CHECK (status IN ('active','inactive','suspended')) | Account status               |
| `last_login` | TIMESTAMPTZ | nullable                                                                        | Last login timestamp         |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW()                                                                   | Last update timestamp        |

**Helper Functions:**

-   `update_user_last_login(user_id UUID)` - Call this after successful login to update last_login

**Row Level Security (RLS) Policies:**

-   Users can view and update their own profile
-   Admins can view and update all profiles

### 2. `audit_logs` Table

This table tracks all administrative actions for compliance and security monitoring.

| Column          | Type        | Constraints                                                             | Description                                      |
| --------------- | ----------- | ----------------------------------------------------------------------- | ------------------------------------------------ |
| `id`            | UUID        | PRIMARY KEY, DEFAULT gen_random_uuid()                                  | Unique audit log ID                              |
| `admin_user_id` | UUID        | NOT NULL, REFERENCES profiles(id) ON DELETE CASCADE                     | Admin who performed the action                   |
| `action_type`   | TEXT        | NOT NULL, CHECK (action_type IN ('create', 'update', 'delete', 'view')) | Type of action performed                         |
| `table_name`    | TEXT        | NOT NULL                                                                | Name of the affected table                       |
| `record_id`     | UUID        | nullable                                                                | ID of the affected record                        |
| `old_values`    | JSONB       | nullable                                                                | Previous values before update                    |
| `new_values`    | JSONB       | nullable                                                                | New values after update/create                   |
| `metadata`      | JSONB       | nullable                                                                | Additional context (IP, timestamp details, etc.) |
| `created_at`    | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()                                                 | When the action occurred                         |

**Indexes:**

-   `admin_user_id` - Fast lookup by admin
-   `action_type` - Filter by action type
-   `table_name` - Filter by affected table
-   `created_at` - Time-based queries
-   Composite: `(table_name, action_type, created_at)` - Common query pattern

**Row Level Security (RLS) Policies:**

-   Only admins can view audit logs
-   Only admins can insert audit logs (immutable - no updates/deletes)

### 3. `items` Table

### 2. `items` Table

This table stores all the borrowed item records.

| Column                | Type        | Constraints                                                              | Description                  |
| --------------------- | ----------- | ------------------------------------------------------------------------ | ---------------------------- |
| `id`                  | UUID        | PRIMARY KEY, DEFAULT gen_random_uuid()                                   | Unique item ID               |
| `user_id`             | UUID        | NOT NULL, REFERENCES auth.users(id) ON DELETE CASCADE                    | Owner of the item            |
| `name`                | TEXT        | NOT NULL, CHECK (char_length >= 3)                                       | Item name                    |
| `photo_url`           | TEXT        | nullable                                                                 | URL to item photo in storage |
| `borrower_name`       | TEXT        | NOT NULL, CHECK (char_length >= 3)                                       | Name of borrower             |
| `borrower_contact_id` | TEXT        | nullable                                                                 | Contact info of borrower     |
| `borrow_date`         | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()                                                  | When item was borrowed       |
| `due_date`            | DATE        | nullable                                                                 | Due date for return          |
| `return_date`         | DATE        | nullable                                                                 | Actual return date           |
| `status`              | TEXT        | NOT NULL, DEFAULT 'borrowed', CHECK (status IN ('borrowed', 'returned')) | Current status               |
| `notes`               | TEXT        | nullable                                                                 | Additional notes             |
| `created_at`          | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()                                                  | Record creation time         |

**Row Level Security (RLS) Policies:**

-   Users can view, insert, update, and delete their own items
-   Admins can view, insert, update, and delete all items

### 4. Storage Bucket: `item_photos`

This bucket stores photos of borrowed items.

**Structure:** `{user_id}/{item_id}.jpg`

**Row Level Security (RLS) Policies:**

-   Users can view, upload, and delete photos in their own folder (matched by user_id)
-   Admins can view, upload, and delete all photos

## Migrations

Migrations are located in `sql/migrations/` and should be applied in order:

1. **001_add_profiles_and_admin_rls.sql** - Creates profiles table and adds admin role support to RLS policies
2. **002_create_audit_logs.sql** - Creates audit_logs table for tracking admin actions (upcoming)
3. **003_update_profiles_admin.sql** - Adds status and last_login to profiles (upcoming)

## Notes

-   All tables have Row Level Security (RLS) enabled
-   Admin users have `role='admin'` in the `profiles` table
-   Regular users have `role='user'` in the `profiles` table
-   After creating a new user via Supabase Auth, a profile record should be automatically created (via trigger or manual insert)
