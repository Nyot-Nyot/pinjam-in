# How to Apply Migration 012

## Issue

The `admin_get_all_users` and `admin_get_user_details` functions reference `i.owner_id` but the items table uses `i.user_id` column.

## Error Message

```
PostgrestException(message: column i.owner_id does not exist, code: 42703, details: Bad Request, hint: Perhaps you meant to reference the column "i.user_id".)
```

## Solution

Apply migration `012_fix_owner_id_to_user_id.sql`

## Steps to Apply (via Supabase Dashboard)

1. **Open Supabase Dashboard**

    - Go to https://supabase.com/dashboard
    - Select your project: pinjam-in

2. **Navigate to SQL Editor**

    - Click on "SQL Editor" in the left sidebar
    - Click "New query"

3. **Copy & Paste Migration**

    - Open file: `sql/migrations/012_fix_owner_id_to_user_id.sql`
    - Copy the entire contents
    - Paste into SQL Editor

4. **Run the Migration**

    - Click "Run" button (or press Ctrl/Cmd + Enter)
    - Wait for confirmation message
    - Should see: "✅ Migration 012 completed successfully"

5. **Verify the Fix**
    - Hot reload the Flutter app (press 'r')
    - Navigate to Admin → Users
    - Users list should now load successfully

## Alternative: Command Line (if using Supabase CLI)

```bash
# If you have supabase CLI installed
cd /home/nyotnyot/Project/Kuliah/Semester_5/PSB/pinjam_in
supabase db push --file sql/migrations/012_fix_owner_id_to_user_id.sql
```

## What the Migration Does

1. **Fixes `admin_get_all_users` function**:

    - Changes `LEFT JOIN public.items i ON i.owner_id = p.id`
    - To: `LEFT JOIN public.items i ON i.user_id = p.id`

2. **Fixes `admin_get_user_details` function**:

    - Changes `LEFT JOIN public.items i ON i.owner_id = p.id`
    - To: `LEFT JOIN public.items i ON i.user_id = p.id`

3. **Also fixes status values**:
    - Changed from `'available'/'unavailable'` to `'borrowed'/'returned'`
    - Matches the actual items table schema

## After Migration

The users list screen will:

-   ✅ Load all users successfully
-   ✅ Show correct item counts
-   ✅ Show borrowed vs returned item counts
-   ✅ Allow search and filtering
