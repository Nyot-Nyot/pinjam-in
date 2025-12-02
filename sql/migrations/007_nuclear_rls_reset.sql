-- NUCLEAR OPTION: Complete RLS Reset
-- Filename: sql/migrations/007_nuclear_rls_reset.sql
-- Purpose: Completely reset ALL RLS policies and rebuild from scratch
--
-- Use this if migration 006 didn't work because old policies are stuck
--
-- WARNING: This will DROP ALL POLICIES on all tables!

BEGIN;

-- ============================================================================
-- STEP 1: DISABLE RLS ON ALL TABLES (EXCEPT STORAGE.OBJECTS)
-- ============================================================================
-- Note: We don't touch storage.objects because it requires superuser privileges
ALTER TABLE IF EXISTS public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.audit_logs DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE IF EXISTS storage.objects DISABLE ROW LEVEL SECURITY; -- Skip: requires superuser

-- ============================================================================
-- STEP 2: DROP ALL EXISTING POLICIES
-- ============================================================================

-- Drop ALL policies on profiles
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
  END LOOP;
END $$;

-- Drop ALL policies on items
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'items'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.items', pol.policyname);
  END LOOP;
END $$;

-- Drop ALL policies on audit_logs
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'audit_logs'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.audit_logs', pol.policyname);
  END LOOP;
END $$;

-- Drop ALL policies on storage.objects
-- Note: We use a TRY-CATCH approach because storage.objects may need superuser
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
  LOOP
    BEGIN
      EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
    EXCEPTION WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping storage policy %: insufficient privileges', pol.policyname;
    END;
  END LOOP;
END $$;

-- ============================================================================
-- STEP 3: ENSURE is_admin() FUNCTION EXISTS AND IS CORRECT
-- ============================================================================

-- Drop and recreate is_admin() to ensure it's correct
DROP FUNCTION IF EXISTS public.is_admin(UUID);

CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- SECURITY DEFINER allows this function to bypass RLS
  -- This prevents infinite recursion when checking admin status
  RETURN EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = user_id
    AND role = 'admin'
    AND status = 'active'
  );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated;

-- ============================================================================
-- STEP 4: PROFILES TABLE - SIMPLE RLS (NO ADMIN CHECK)
-- ============================================================================

-- Simple policies for profiles - NO admin checking to avoid recursion
-- Admin operations should use service role

CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Re-enable RLS with simple policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 5: ITEMS TABLE - WITH ADMIN CHECK USING is_admin()
-- ============================================================================
-- Note: Items table structure:
--   - user_id: Owner of the item (lender)
--   - borrower_name: Name of borrower (TEXT, not UUID)
--   - status: 'borrowed' or 'returned'

-- Users can view their own items OR admins can view all
CREATE POLICY "Users can view own items or admins view all" ON public.items
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_admin(auth.uid())
  );

-- Users can insert their own items OR admins can insert any
CREATE POLICY "Users can create own items or admins create any" ON public.items
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    OR public.is_admin(auth.uid())
  );

-- Users can update their own items OR admins can update any
CREATE POLICY "Users can update own items or admins update any" ON public.items
  FOR UPDATE
  USING (
    user_id = auth.uid()
    OR public.is_admin(auth.uid())
  )
  WITH CHECK (
    user_id = auth.uid()
    OR public.is_admin(auth.uid())
  );

-- Only admins can delete items
CREATE POLICY "Only admins can delete items" ON public.items
  FOR DELETE
  USING (public.is_admin(auth.uid()));

-- Re-enable RLS
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;-- ============================================================================
-- STEP 6: AUDIT_LOGS TABLE - WITH ADMIN CHECK USING is_admin()
-- ============================================================================

-- Only admins can view audit logs
CREATE POLICY "Only admins can view audit logs" ON public.audit_logs
  FOR SELECT
  USING (public.is_admin(auth.uid()));

-- System can insert audit logs (via triggers)
-- Admins can also insert manually if needed
CREATE POLICY "System or admins can insert audit logs" ON public.audit_logs
  FOR INSERT
  WITH CHECK (public.is_admin(auth.uid()));

-- Re-enable RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 7: STORAGE.OBJECTS - WITH ADMIN CHECK USING is_admin()
-- ============================================================================
-- Note: Storage policies may fail due to permissions. Skip if error occurs.
-- You can create these policies manually in Supabase dashboard if needed.

-- Users can view their own files OR admins can view all
DO $$
BEGIN
  EXECUTE 'CREATE POLICY "Users can view own files or admins view all" ON storage.objects
    FOR SELECT
    USING (
      bucket_id = ''item-images''
      AND (
        auth.uid()::text = (storage.foldername(name))[1]
        OR public.is_admin(auth.uid())
      )
    )';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'Skipping storage SELECT policy: insufficient privileges';
END $$;

-- Users can insert their own files OR admins can insert any
DO $$
BEGIN
  EXECUTE 'CREATE POLICY "Users can upload own files or admins upload any" ON storage.objects
    FOR INSERT
    WITH CHECK (
      bucket_id = ''item-images''
      AND (
        auth.uid()::text = (storage.foldername(name))[1]
        OR public.is_admin(auth.uid())
      )
    )';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'Skipping storage INSERT policy: insufficient privileges';
END $$;

-- Users can update their own files OR admins can update any
DO $$
BEGIN
  EXECUTE 'CREATE POLICY "Users can update own files or admins update any" ON storage.objects
    FOR UPDATE
    USING (
      bucket_id = ''item-images''
      AND (
        auth.uid()::text = (storage.foldername(name))[1]
        OR public.is_admin(auth.uid())
      )
    )
    WITH CHECK (
      bucket_id = ''item-images''
      AND (
        auth.uid()::text = (storage.foldername(name))[1]
        OR public.is_admin(auth.uid())
      )
    )';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'Skipping storage UPDATE policy: insufficient privileges';
END $$;

-- Re-enable RLS (skip if permission error)
-- DO $$
-- BEGIN
--   ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
-- EXCEPTION WHEN insufficient_privilege THEN
--   RAISE NOTICE 'Cannot enable RLS on storage.objects: insufficient privileges';
-- END $$;
COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- After running this migration, test with these queries:

-- 1. Check is_admin() works
-- SELECT public.is_admin(auth.uid());

-- 2. Check profiles query works
-- SELECT * FROM public.profiles WHERE id = auth.uid();

-- 3. Check items query works
-- SELECT * FROM public.items LIMIT 5;

-- 4. Check audit_logs query works (should be empty or error if not admin)
-- SELECT * FROM public.audit_logs LIMIT 5;

-- 5. List all policies to confirm
-- SELECT tablename, policyname FROM pg_policies WHERE schemaname IN ('public', 'storage') ORDER BY tablename, policyname;
