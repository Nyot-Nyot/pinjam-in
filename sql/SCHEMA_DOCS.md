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

-   **SELECT**: Users can view own profile OR admins can view all profiles
-   **UPDATE**: Users can update own profile OR admins can update all profiles
-   **INSERT**: Users can insert own profile OR admins can insert any profile
-   **DELETE**: Only admins can delete profiles (regular users cannot delete their own)

**Policy Details:**

All policies use the pattern: `auth.uid() = id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')` to allow both owner access and admin bypass.

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

-   **SELECT**: Only admins can view audit logs
-   **INSERT**: Only admins can insert audit logs
-   **UPDATE/DELETE**: Not allowed (audit logs are immutable for compliance)

**Policy Details:**

All policies check: `EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')` to ensure only admins have access.

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

-   **SELECT**: Users can view own items OR admins can view all items
-   **INSERT**: Users can insert own items OR admins can insert any items
-   **UPDATE**: Users can update own items OR admins can update all items
-   **DELETE**: Users can delete own items OR admins can delete all items

**Policy Details:**

All policies use the pattern: `auth.uid() = user_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')` to allow both owner access and admin bypass.

### 4. Storage Bucket: `item_photos`

This bucket stores photos of borrowed items.

**Structure:** `{user_id}/{item_id}.jpg`

**Row Level Security (RLS) Policies:**

-   **SELECT**: Users can view photos in their own folder OR admins can view all photos
-   **INSERT**: Users can upload photos to their own folder OR admins can upload anywhere
-   **UPDATE**: Users can update photos in their own folder OR admins can update all photos
-   **DELETE**: Users can delete photos in their own folder OR admins can delete all photos

**Policy Details:**

All policies check bucket_id = 'item_photos' AND (auth.uid()::text = (storage.foldername(name))[1] OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')) to allow both owner access and admin bypass.

## Admin Functions

The following functions provide admin-level operations with built-in security, validation, and audit logging. All functions require admin privileges and use `SECURITY DEFINER` to bypass RLS policies.

### Helper Functions

#### `create_admin_audit_log()`

Creates a standardized audit log entry for admin actions.

**Signature:**

```sql
create_admin_audit_log(
  admin_user_id UUID,
  action_type TEXT,
  table_name TEXT,
  record_id UUID,
  old_values JSONB DEFAULT NULL,
  new_values JSONB DEFAULT NULL,
  metadata JSONB DEFAULT NULL
) RETURNS UUID
```

**Returns:** UUID of created audit log entry

**Usage:**

```sql
SELECT create_admin_audit_log(
  auth.uid(),
  'update',
  'profiles',
  'user-id-here',
  jsonb_build_object('role', 'user'),
  jsonb_build_object('role', 'admin'),
  jsonb_build_object('action', 'role_promotion')
);
```

### User Management Functions

#### `admin_get_all_users()`

Retrieve a paginated list of all users with statistics and optional filtering.

**Signature:**

```sql
admin_get_all_users(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  role_filter TEXT DEFAULT NULL,
  status_filter TEXT DEFAULT NULL,
  search TEXT DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  email TEXT,
  full_name TEXT,
  role TEXT,
  status TEXT,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  items_count INT,
  borrowed_items INT,
  returned_items INT
)
```

**Parameters:**

-   `p_limit`: Maximum number of results (default: 50)
-   `p_offset`: Number of records to skip for pagination (default: 0)
-   `role_filter`: Filter by role ('user', 'admin', or NULL for all)
-   `status_filter`: Filter by status ('active', 'inactive', 'suspended', or NULL for all)
-   `search`: Search in full_name or email (case-insensitive, partial match)

**Returns:** Table with user information and item statistics

**Example:**

```sql
-- Get first 20 active users
SELECT * FROM admin_get_all_users(20, 0, NULL, 'active', NULL);

-- Search for users with 'john' in name or email
SELECT * FROM admin_get_all_users(50, 0, NULL, NULL, 'john');

-- Get all admin users
SELECT * FROM admin_get_all_users(50, 0, 'admin', NULL, NULL);
```

#### `admin_get_user_details()`

Get comprehensive details for a specific user including activity metrics.

**Signature:**

```sql
admin_get_user_details(p_user_id UUID) RETURNS TABLE (
  id UUID,
  email TEXT,
  full_name TEXT,
  role TEXT,
  status TEXT,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  total_items INT,
  borrowed_items INT,
  returned_items INT,
  overdue_items INT,
  storage_files_count INT
)
```

**Parameters:**

-   `p_user_id`: UUID of the user to retrieve

**Returns:** Single row with complete user details and metrics

**Raises:** Exception if user not found

**Example:**

```sql
SELECT * FROM admin_get_user_details('550e8400-e29b-41d4-a716-446655440000');
```

#### `admin_update_user_role()`

Update a user's role with validation and audit logging.

**Signature:**

```sql
admin_update_user_role(
  p_user_id UUID,
  new_role TEXT
) RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  user_id UUID,
  old_role TEXT,
  new_role TEXT
)
```

**Parameters:**

-   `p_user_id`: UUID of the user to update
-   `new_role`: New role ('user' or 'admin')

**Returns:** Result with old and new role values

**Security:**

-   Prevents admin from demoting themselves
-   Validates role is 'user' or 'admin'
-   Creates audit log with old/new values

**Raises:**

-   Exception if user not found
-   Exception if invalid role
-   Exception if trying to demote self

**Example:**

```sql
-- Promote user to admin
SELECT * FROM admin_update_user_role('user-id', 'admin');

-- Demote admin to user (will fail if it's yourself)
SELECT * FROM admin_update_user_role('user-id', 'user');
```

#### `admin_update_user_status()`

Update a user's account status with validation and audit logging.

**Signature:**

```sql
admin_update_user_status(
  p_user_id UUID,
  new_status TEXT,
  reason TEXT DEFAULT NULL
) RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  user_id UUID,
  old_status TEXT,
  new_status TEXT
)
```

**Parameters:**

-   `p_user_id`: UUID of the user to update
-   `new_status`: New status ('active', 'inactive', or 'suspended')
-   `reason`: Optional reason for status change (stored in audit log)

**Returns:** Result with old and new status values

**Security:**

-   Prevents admin from deactivating themselves
-   Validates status is valid value
-   Creates audit log with reason

**Raises:**

-   Exception if user not found
-   Exception if invalid status
-   Exception if trying to deactivate self

**Example:**

```sql
-- Suspend user
SELECT * FROM admin_update_user_status('user-id', 'suspended', 'Violation of terms');

-- Reactivate user
SELECT * FROM admin_update_user_status('user-id', 'active', 'Appeal accepted');
```

#### `admin_delete_user()`

Delete a user account with soft or hard delete options.

**Signature:**

```sql
admin_delete_user(
  p_user_id UUID,
  hard_delete BOOLEAN DEFAULT FALSE,
  reason TEXT DEFAULT NULL
) RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  deleted_user_id UUID,
  delete_type TEXT,
  items_affected INT
)
```

**Parameters:**

-   `p_user_id`: UUID of the user to delete
-   `hard_delete`: If FALSE (default), soft delete; if TRUE, permanent deletion
-   `reason`: Optional reason for deletion (stored in audit log)

**Soft Delete:**

-   Sets user status to 'inactive'
-   Preserves all user data, items, and files
-   User can potentially be reactivated

**Hard Delete:**

-   Removes user from auth.users table
-   CASCADE deletes all associated items and audit logs
-   Removes user files from storage (if implemented)
-   **This is permanent and cannot be undone**

**Security:**

-   Prevents admin from deleting themselves
-   Creates audit log before deletion
-   Different messages for soft vs hard delete

**Raises:**

-   Exception if user not found
-   Exception if trying to delete self

**Example:**

```sql
-- Soft delete (recommended)
SELECT * FROM admin_delete_user('user-id', FALSE, 'Account closure requested');

-- Hard delete (use with extreme caution)
SELECT * FROM admin_delete_user('user-id', TRUE, 'Legal requirement');
```

### Items Management Functions

These functions allow admins to manage items in the system, including viewing, updating status, and deleting items.

#### `admin_get_all_items(limit, offset, status_filter, user_filter, search)`

Get paginated list of all items with owner information and filtering options.

**Parameters:**

-   `p_limit` (INTEGER, default: 50) - Number of items to return
-   `p_offset` (INTEGER, default: 0) - Number of items to skip (for pagination)
-   `p_status_filter` (TEXT, optional) - Filter by status ('available', 'borrowed', 'unavailable')
-   `p_user_filter` (UUID, optional) - Filter by owner user ID
-   `p_search` (TEXT, optional) - Search in item name, borrower name, or notes

**Returns TABLE:**

-   `id` (UUID) - Item ID
-   `item_name` (TEXT) - Name of the item
-   `borrower_name` (TEXT) - Name of the borrower
-   `contact_info` (TEXT) - Contact information
-   `borrow_date` (TIMESTAMPTZ) - When item was borrowed
-   `return_date` (TIMESTAMPTZ) - Expected return date
-   `status` (TEXT) - Current status
-   `notes` (TEXT) - Additional notes
-   `photo_url` (TEXT) - Photo URL
-   `owner_id` (UUID) - Owner user ID
-   `owner_name` (TEXT) - Owner's full name
-   `owner_email` (VARCHAR) - Owner's email
-   `created_at` (TIMESTAMPTZ) - Creation timestamp
-   `updated_at` (TIMESTAMPTZ) - Last update timestamp
-   `is_overdue` (BOOLEAN) - True if borrowed and past return date
-   `days_borrowed` (INTEGER) - Number of days since borrow date

**Permissions:** Admin only

**Features:**

-   Supports multiple filter types (status, owner, search)
-   Automatically sorts overdue items first
-   Calculates if item is overdue
-   Shows owner information with email
-   Full-text search across item name, borrower, and notes

**Example:**

```sql
-- Get all items
SELECT * FROM admin_get_all_items();

-- Get borrowed items only
SELECT * FROM admin_get_all_items(50, 0, 'borrowed', NULL, NULL);

-- Get items owned by specific user
SELECT * FROM admin_get_all_items(50, 0, NULL, 'user-uuid', NULL);

-- Search for items containing "laptop"
SELECT * FROM admin_get_all_items(50, 0, NULL, NULL, 'laptop');
```

#### `admin_get_item_details(item_id)`

Get complete details for a specific item including owner and borrower information.

**Parameters:**

-   `p_item_id` (UUID) - The item ID to retrieve

**Returns TABLE:**

-   All item fields (id, item_name, borrower_name, etc.)
-   Owner information (owner_id, owner_name, owner_email, owner_role, owner_status)
-   Computed fields:
    -   `is_overdue` (BOOLEAN) - Whether item is overdue
    -   `days_borrowed` (INTEGER) - Days since borrowed
    -   `days_overdue` (INTEGER) - Days past return date (if overdue)
    -   `owner_total_items` (BIGINT) - Total items owned by this user
    -   `owner_borrowed_items` (BIGINT) - Currently borrowed items by this user

**Permissions:** Admin only

**Raises:**

-   Exception if item not found

**Example:**

```sql
SELECT * FROM admin_get_item_details('item-uuid');
```

#### `admin_update_item_status(item_id, new_status, reason)`

Update an item's status with audit logging.

**Parameters:**

-   `p_item_id` (UUID) - The item ID to update
-   `p_new_status` (TEXT) - New status ('available', 'borrowed', 'unavailable')
-   `p_reason` (TEXT, optional) - Reason for status change (logged in audit)

**Returns TABLE:**

-   `item_id` (UUID) - The item ID
-   `item_name` (TEXT) - Name of the item
-   `old_status` (TEXT) - Previous status
-   `new_status` (TEXT) - New status
-   `message` (TEXT) - Confirmation message

**Permissions:** Admin only

**Features:**

-   Validates status values
-   Prevents setting same status
-   Creates audit log with old/new values
-   Records reason in audit metadata

**Raises:**

-   Exception if item not found
-   Exception if invalid status provided
-   Exception if status is already the new value

**Valid Status Values:**

-   `available` - Item is available and not borrowed
-   `borrowed` - Item is currently borrowed
-   `unavailable` - Item is not available (lost, damaged, soft deleted)

**Example:**

```sql
-- Mark item as returned
SELECT * FROM admin_update_item_status('item-id', 'available', 'Item returned in good condition');

-- Mark item as unavailable
SELECT * FROM admin_update_item_status('item-id', 'unavailable', 'Item damaged and under repair');
```

#### `admin_delete_item(item_id, hard_delete, reason)`

Delete an item with optional hard delete and audit logging.

**Parameters:**

-   `p_item_id` (UUID) - The item ID to delete
-   `p_hard_delete` (BOOLEAN, default: FALSE) - Whether to permanently delete
-   `p_reason` (TEXT, optional) - Reason for deletion (logged in audit)

**Returns TABLE:**

-   `item_id` (UUID) - The item ID
-   `item_name` (TEXT) - Name of the item
-   `delete_type` (TEXT) - 'soft_delete' or 'hard_delete'
-   `message` (TEXT) - Confirmation message

**Permissions:** Admin only

**Soft Delete (default):**

-   Sets item status to 'unavailable'
-   Item remains in database
-   Can be recovered by changing status back to 'available'
-   Creates audit log with action='update'

**Hard Delete:**

-   Permanently removes item from database
-   **Cannot be undone**
-   Creates audit log with full item data snapshot
-   **Note:** Does NOT delete photo from storage automatically

**Raises:**

-   Exception if item not found

**Example:**

```sql
-- Soft delete (recommended)
SELECT * FROM admin_delete_item('item-id', FALSE, 'Owner requested removal');

-- Hard delete (permanent - use with caution)
SELECT * FROM admin_delete_item('item-id', TRUE, 'Legal compliance requirement');
```

**Important Notes:**

-   Hard delete does not remove photos from Supabase Storage
-   Use storage management tools to clean up orphaned files
-   Audit logs will capture full item data before hard delete
-   Soft delete is reversible, hard delete is not

## Migrations

Migrations are located in `sql/migrations/` and should be applied in order:

1. **001_add_profiles_and_admin_rls.sql** - Creates profiles table and adds admin role support to items and storage RLS policies
2. **002_create_audit_logs.sql** - Creates audit_logs table for tracking admin actions with indexes and RLS
3. **003_update_profiles_admin.sql** - Adds status and last_login columns to profiles with helper functions
4. **004_admin_rls_policies.sql** - Enables RLS on profiles table and adds comprehensive admin bypass policies for all tables
5. **005_add_is_admin_function.sql** - Creates helper function for checking admin role
6. **006_fix_rls_infinite_recursion.sql** - Fixes infinite recursion in RLS policies by using is_admin function
7. **007_remove_old_admin_check.sql** - Removes redundant admin_users table from old implementation
8. **008_admin_functions_users.sql** - Creates admin functions for user management operations
9. **008b_admin_functions_test_helpers.sql** - Test helper functions for user management (SQL Editor testing only)
10. **008c_fix_email_type.sql** - Fixes email type mismatch in user management functions
11. **009_admin_functions_items.sql** - Creates admin functions for items management operations
12. **009b_admin_functions_items_test_helpers.sql** - Test helper functions for items management (SQL Editor testing only)

## Notes

-   All tables have Row Level Security (RLS) enabled
-   Admin users have `role='admin'` in the `profiles` table
-   Regular users have `role='user'` in the `profiles` table
-   Admin functions use `SECURITY DEFINER` to bypass RLS and perform elevated operations
-   All admin operations are logged in the `audit_logs` table
-   After creating a new user via Supabase Auth, a profile record should be automatically created (via trigger or manual insert)
