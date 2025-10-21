# Database Migrations

## How to Apply Migrations

### Option 1: Via Supabase Dashboard (Recommended)

1. Open [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **SQL Editor** in the left sidebar
4. Click **New Query**
5. Copy the SQL from the migration file below
6. Click **Run** or press `Ctrl+Enter`

### Option 2: Via Supabase CLI

```bash
supabase db push
```

---

## Migration: Add `due_date` Column

**File:** `001_add_due_date.sql`

Run this SQL in Supabase SQL Editor:

```sql
-- Add due_date column to items table
ALTER TABLE public.items
ADD COLUMN IF NOT EXISTS due_date DATE;

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_items_due_date ON public.items(due_date);

-- Add comment to document the column
COMMENT ON COLUMN public.items.due_date IS 'Target return date for the borrowed item';
```

**Purpose:** This migration adds the `due_date` column to store the expected/target return date for borrowed items. This is different from `return_date` which stores the actual return date.

**Impact:**

-   ✅ Enables storing target return dates
-   ✅ Allows calculating days remaining until due date
-   ✅ Existing data is not affected (column is nullable)
