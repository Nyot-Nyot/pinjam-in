-- Migration: Update profiles table for admin features
-- Filename: sql/migrations/003_update_profiles_admin.sql
-- Purpose: Add status and last_login columns to profiles table
-- and create trigger to automatically update last_login on auth

BEGIN;

-- ============================================================
-- ADD NEW COLUMNS TO PROFILES TABLE
-- ============================================================
-- Add status column to track user account status
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS status TEXT
  NOT NULL DEFAULT 'active'
  CHECK (status IN ('active', 'inactive', 'suspended'));

-- Add last_login column to track user login activity
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ;

-- ============================================================
-- CREATE TRIGGER FUNCTION TO UPDATE LAST_LOGIN
-- ============================================================
-- This function will be called whenever a user logs in
CREATE OR REPLACE FUNCTION public.update_last_login()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles
  SET last_login = NOW()
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- CREATE TRIGGER ON AUTH.USERS
-- ============================================================
-- Note: This trigger may not work directly on auth.users (Supabase managed)
-- Alternative approach: Update last_login from application code after successful login
-- or use a database function that's called on login

-- If you have access to auth.users, uncomment this:
-- CREATE TRIGGER on_auth_user_login
--   AFTER UPDATE OF last_sign_in_at ON auth.users
--   FOR EACH ROW
--   WHEN (OLD.last_sign_in_at IS DISTINCT FROM NEW.last_sign_in_at)
--   EXECUTE FUNCTION public.update_last_login();

-- ============================================================
-- CREATE HELPER FUNCTION FOR MANUAL LAST_LOGIN UPDATE
-- ============================================================
-- Call this function from your app after successful login
CREATE OR REPLACE FUNCTION public.update_user_last_login(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.profiles
  SET last_login = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- SEED EXISTING USERS WITH DEFAULT STATUS
-- ============================================================
-- Set all existing profiles to 'active' status if they don't have one
UPDATE public.profiles
SET status = 'active'
WHERE status IS NULL;

COMMIT;

-- ============================================================
-- VERIFICATION QUERIES (Run these to test)
-- ============================================================
-- Test: Verify new columns were added
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'profiles'
-- AND column_name IN ('status', 'last_login')
-- ORDER BY ordinal_position;

-- Test: Verify function was created
-- SELECT proname, prosrc
-- FROM pg_proc
-- WHERE proname IN ('update_last_login', 'update_user_last_login');

-- Test: Verify all users have status
-- SELECT id, full_name, role, status, last_login
-- FROM public.profiles
-- LIMIT 10;

-- Test: Manually update last_login for current user
-- SELECT public.update_user_last_login(auth.uid());
-- SELECT * FROM public.profiles WHERE id = auth.uid();
