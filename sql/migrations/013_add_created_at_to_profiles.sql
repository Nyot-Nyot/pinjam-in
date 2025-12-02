-- Migration 013: Add created_at column to profiles table
-- Date: 2025-12-02
-- Issue: profiles table is missing created_at column
--        Function admin_get_user_details tries to select p.created_at but column doesn't exist
-- Fix: Add created_at column to profiles table

-- Check if column exists first
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'created_at'
  ) THEN
    -- Add created_at column
    ALTER TABLE public.profiles
    ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();

    RAISE NOTICE '✅ Added created_at column to profiles table';
  ELSE
    RAISE NOTICE 'ℹ️ Column created_at already exists in profiles table';
  END IF;

  -- Ensure updated_at column exists too
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'updated_at'
  ) THEN
    -- Add updated_at column
    ALTER TABLE public.profiles
    ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();

    RAISE NOTICE '✅ Added updated_at column to profiles table';
  ELSE
    RAISE NOTICE 'ℹ️ Column updated_at already exists in profiles table';
  END IF;
END $$;

-- Update existing NULL values
UPDATE public.profiles
SET created_at = NOW()
WHERE created_at IS NULL;

UPDATE public.profiles
SET updated_at = NOW()
WHERE updated_at IS NULL;

-- Create trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION public.update_profiles_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS profiles_updated_at_trigger ON public.profiles;

CREATE TRIGGER profiles_updated_at_trigger
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_profiles_updated_at();

-- Verification
DO $$
DECLARE
  has_created_at BOOLEAN;
  has_updated_at BOOLEAN;
BEGIN
  -- Check created_at
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'created_at'
  ) INTO has_created_at;

  -- Check updated_at
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'updated_at'
  ) INTO has_updated_at;

  RAISE NOTICE '';
  RAISE NOTICE '=== Migration 013 Verification ===';
  RAISE NOTICE 'profiles.created_at exists: %', has_created_at;
  RAISE NOTICE 'profiles.updated_at exists: %', has_updated_at;
  RAISE NOTICE '';

  IF has_created_at AND has_updated_at THEN
    RAISE NOTICE '✅ Migration 013 completed successfully!';
  ELSE
    RAISE EXCEPTION '❌ Migration 013 failed - columns not created';
  END IF;
END $$;
