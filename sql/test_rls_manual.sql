-- Quick RLS Test (Manual UUID Version)
-- Purpose: Test RLS policies without requiring auth.uid()
-- Use this if you cannot use Supabase SQL Editor with authentication

-- ============================================================================
-- STEP 1: GET YOUR USER ID FIRST
-- ============================================================================
-- Run this query to get your user ID:
-- SELECT id, full_name, role FROM public.profiles;

-- Then replace 'YOUR_USER_ID_HERE' below with actual UUID

-- ============================================================================
-- CONFIGURATION: Set your user ID here
-- ============================================================================
\set test_user_id 'YOUR_USER_ID_HERE'

-- Or manually replace in each query below

-- ============================================================================
-- TEST 1: Check is_admin() function works (no recursion)
-- ============================================================================
SELECT
  '=== TEST 1: is_admin() Function ===' as test_section,
  public.is_admin('YOUR_USER_ID_HERE'::UUID) as is_admin_result;

-- Expected: Should return true or false without recursion error

-- ============================================================================
-- TEST 2: List all policies on profiles table
-- ============================================================================
SELECT
  '=== TEST 2: Profiles Policies ===' as test_section,
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'profiles';

-- Expected: Should see simple policies without admin checks

-- ============================================================================
-- TEST 3: List all policies on items table
-- ============================================================================
SELECT
  '=== TEST 3: Items Policies ===' as test_section,
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'items';

-- Expected: Should see policies using is_admin()

-- ============================================================================
-- TEST 4: List all policies on audit_logs table
-- ============================================================================
SELECT
  '=== TEST 4: Audit Logs Policies ===' as test_section,
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'audit_logs';

-- Expected: Should see policies using is_admin()

-- ============================================================================
-- TEST 5: Check RLS is enabled on all tables
-- ============================================================================
SELECT
  '=== TEST 5: RLS Status ===' as test_section,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'items', 'audit_logs')
ORDER BY tablename;

-- Expected: All should show rls_enabled = true

-- ============================================================================
-- TEST 6: Verify is_admin() function definition
-- ============================================================================
SELECT
  '=== TEST 6: is_admin() Function ===' as test_section,
  routine_name,
  security_type,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'is_admin';

-- Expected: Should show SECURITY DEFINER

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
SELECT '=== ALL TESTS COMPLETED ===' as summary;

-- If all queries above run without recursion errors, RLS is fixed! ✅
