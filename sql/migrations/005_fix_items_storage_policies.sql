-- Migration: Fix infinite recursion in items and storage policies
-- Filename: sql/migrations/005_fix_items_storage_policies.sql
-- Purpose: Update items and storage policies to use is_admin() function
-- instead of querying profiles table directly (which causes infinite recursion)
--
-- This migration updates policies created in migration 001 to use the
-- is_admin() function created in migration 004.

BEGIN;

-- ============================================================================
-- 1. UPDATE ITEMS TABLE POLICIES
-- ============================================================================
-- Drop existing policies from migration 001
DROP POLICY IF EXISTS "Allow users to view own items or admins" ON public.items;
DROP POLICY IF EXISTS "Allow users to insert own items or admins" ON public.items;
DROP POLICY IF EXISTS "Allow users to update own items or admins" ON public.items;
DROP POLICY IF EXISTS "Allow users to delete own items or admins" ON public.items;

-- Recreate with is_admin() function
CREATE POLICY "Allow users to view own items or admins" ON public.items
  FOR SELECT USING (
    auth.uid() = user_id
    OR public.is_admin(auth.uid())
  );

CREATE POLICY "Allow users to insert own items or admins" ON public.items
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin(auth.uid())
  );

CREATE POLICY "Allow users to update own items or admins" ON public.items
  FOR UPDATE USING (
    auth.uid() = user_id
    OR public.is_admin(auth.uid())
  ) WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin(auth.uid())
  );

CREATE POLICY "Allow users to delete own items or admins" ON public.items
  FOR DELETE USING (
    auth.uid() = user_id
    OR public.is_admin(auth.uid())
  );

-- ============================================================================
-- 2. UPDATE STORAGE POLICIES
-- ============================================================================
-- Drop existing policies from migration 001
DROP POLICY IF EXISTS "Allow users to view their own photos or admins" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to upload photos or admins" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own photos or admins" ON storage.objects;

-- Recreate with is_admin() function
CREATE POLICY "Allow users to view their own photos or admins" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'item_photos' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR public.is_admin(auth.uid())
    )
  );

CREATE POLICY "Allow users to upload photos or admins" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'item_photos' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR public.is_admin(auth.uid())
    )
  );

CREATE POLICY "Allow users to delete their own photos or admins" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'item_photos' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR public.is_admin(auth.uid())
    )
  );

-- Note: UPDATE policy for storage was already created in migration 004 using is_admin()

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify the policies are updated correctly:

-- 1. Check items policies
-- SELECT policyname, cmd FROM pg_policies WHERE tablename = 'items';
-- Expected: 4 policies (SELECT, INSERT, UPDATE, DELETE)

-- 2. Check storage policies
-- SELECT policyname, cmd FROM pg_policies
-- WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname LIKE '%photos%';
-- Expected: 4 policies (SELECT, INSERT, UPDATE, DELETE)

-- 3. Test that is_admin() function works
-- SELECT public.is_admin(auth.uid());
-- Expected: true for admin users, false for regular users

-- 4. Test items query doesn't cause recursion
-- SELECT * FROM public.items LIMIT 1;
-- Expected: No error

-- 5. Test profiles query doesn't cause recursion
-- SELECT * FROM public.profiles LIMIT 1;
-- Expected: No error
