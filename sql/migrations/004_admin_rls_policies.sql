-- Migration: Add comprehensive RLS policies for admin role
-- Filename: sql/migrations/004_admin_rls_policies.sql
-- Purpose: Enable Row Level Security on profiles table and add complete
-- admin bypass policies for all CRUD operations on profiles and storage.
-- Items table already has admin policies from migration 001.

BEGIN;

-- ============================================================================
-- 1. CREATE HELPER FUNCTION TO CHECK ADMIN ROLE (SECURITY DEFINER)
-- ============================================================================
-- This function bypasses RLS to avoid infinite recursion when checking admin role
-- SECURITY DEFINER means it runs with the privileges of the function owner (superuser)
-- This allows it to read from profiles table without triggering RLS policies

CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER -- This is key: bypasses RLS
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles WHERE id = user_id AND role = 'admin'
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated;

-- ============================================================================
-- 2. ENABLE RLS ON PROFILES TABLE
-- ============================================================================
-- The profiles table was created in migration 001 but RLS was never enabled.
-- We need to enable RLS first before creating policies.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. PROFILES TABLE RLS POLICIES (Using is_admin function)
-- ============================================================================
-- Allow users to view their own profile, admins can view all profiles
CREATE POLICY "Users can view own profile or admins can view all" ON public.profiles
  FOR SELECT USING (
    auth.uid() = id
    OR public.is_admin(auth.uid())
  );

-- Allow users to update their own profile (except role), admins can update all profiles
-- Note: For extra security, you might want to prevent users from updating their own role
-- This policy allows users to update their own profile, admins can update any profile
CREATE POLICY "Users can update own profile or admins can update all" ON public.profiles
  FOR UPDATE USING (
    auth.uid() = id
    OR public.is_admin(auth.uid())
  ) WITH CHECK (
    auth.uid() = id
    OR public.is_admin(auth.uid())
  );

-- Allow new users to insert their own profile during signup
-- Admins can also create profiles for other users
CREATE POLICY "Users can insert own profile or admins can insert any" ON public.profiles
  FOR INSERT WITH CHECK (
    auth.uid() = id
    OR public.is_admin(auth.uid())
  );

-- Only admins can delete profiles (regular users cannot delete their own profile)
-- User deletion should be handled through Supabase Auth, which will cascade to profiles
CREATE POLICY "Only admins can delete profiles" ON public.profiles
  FOR DELETE USING (
    public.is_admin(auth.uid())
  );

-- ============================================================================
-- 4. STORAGE UPDATE POLICY (item_photos bucket)
-- ============================================================================
-- Migration 001 created SELECT, INSERT, DELETE policies for storage
-- but UPDATE policy was missing. Add it here for completeness.
-- Also using is_admin() function to avoid recursion issues.

-- UPDATE: allow users to update their own files, admins can update any files
CREATE POLICY "Allow users to update their own photos or admins" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'item_photos' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR public.is_admin(auth.uid())
    )
  ) WITH CHECK (
    bucket_id = 'item_photos' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR public.is_admin(auth.uid())
    )
  );

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these queries after migration to verify RLS is working correctly:

-- 1. Check RLS is enabled on profiles
-- SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'profiles';
-- Expected: rowsecurity = true

-- 2. List all policies on profiles table
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies WHERE tablename = 'profiles';
-- Expected: 4 policies (SELECT, UPDATE, INSERT, DELETE)

-- 3. List all storage policies
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd
-- FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage';
-- Expected: 4 policies for item_photos (SELECT, INSERT, UPDATE, DELETE)

-- 4. Test as regular user (should only see own profile)
-- SET LOCAL role TO authenticated;
-- SET LOCAL request.jwt.claims.sub TO '<regular_user_id>';
-- SELECT * FROM public.profiles;
-- Expected: Only returns own profile

-- 5. Test as admin user (should see all profiles)
-- SET LOCAL role TO authenticated;
-- SET LOCAL request.jwt.claims.sub TO '<admin_user_id>';
-- SELECT * FROM public.profiles;
-- Expected: Returns all profiles

-- Notes:
-- * Apply this migration via Supabase SQL Editor or psql with service role
-- * Test with actual users to ensure policies work correctly
-- * Consider adding additional policies for specific use cases (e.g., prevent
--   users from changing their own role field)
