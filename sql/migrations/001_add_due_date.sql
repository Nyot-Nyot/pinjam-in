-- Migration: Add due_date column to items table
-- Date: 2025-10-22
-- Description: Add due_date column to store target return date for borrowed items

-- Add the column
ALTER TABLE public.items
ADD COLUMN IF NOT EXISTS due_date DATE;

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_items_due_date ON public.items(due_date);

-- Add comment for documentation
COMMENT ON COLUMN public.items.due_date IS 'Target/expected return date for the borrowed item (different from actual return_date)';

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'items' AND column_name = 'due_date';
