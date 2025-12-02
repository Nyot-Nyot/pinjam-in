-- Rollback Migration 004: Admin RLS Policies
-- Purpose: Remove all policies and function created by migration 004
-- Run this BEFORE re-applying the fixed migration 004

BEGIN;

-- Drop storage UPDATE policy
DROP POLICY IF EXISTS "Allow users to update their own photos or admins" ON storage.objects;

-- Drop profiles policies
DROP POLICY IF EXISTS "Only admins can delete profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile or admins can insert any" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile or admins can update all" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile or admins can view all" ON public.profiles;

-- Disable RLS on profiles (back to migration 001 state)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Drop the is_admin function if it exists
DROP FUNCTION IF EXISTS public.is_admin(UUID);

COMMIT;

-- Verification: Check that policies are removed
SELECT 'Profiles policies removed:' AS status;
SELECT COUNT(*) as count FROM pg_policies WHERE tablename = 'profiles';
-- Expected: 0

SELECT 'Storage UPDATE policy removed:' AS status;
SELECT COUNT(*) as count FROM pg_policies
WHERE tablename = 'objects' AND policyname = 'Allow users to update their own photos or admins';
-- Expected: 0

SELECT 'Profiles RLS disabled:' AS status;
SELECT rowsecurity FROM pg_tables WHERE tablename = 'profiles';
-- Expected: false

SELECT 'is_admin function removed:' AS status;
SELECT COUNT(*) as count FROM pg_proc WHERE proname = 'is_admin';
-- Expected: 0
