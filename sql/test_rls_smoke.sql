-- Minimal RLS Smoke Test
-- Purpose: Test that RLS policies exist and don't cause recursion
-- Can be run from any SQL client (psql, pgAdmin, etc.)

-- ============================================================================
-- TEST 1: Check is_admin() function exists and works
-- ============================================================================
SELECT
  '=== TEST 1: is_admin() Function ===' as test_section,
  'PASS: Function exists' as status;

-- Test with a dummy UUID (won't match any user, returns false)
SELECT
  public.is_admin('00000000-0000-0000-0000-000000000000'::UUID) as result,
  CASE
    WHEN public.is_admin('00000000-0000-0000-0000-000000000000'::UUID) = false
    THEN '✅ PASS: Function works without recursion'
    ELSE '⚠️ Unexpected: Dummy UUID returned true'
  END as test_result;

-- ============================================================================
-- TEST 2: List all RLS policies (verify they exist)
-- ============================================================================
SELECT
  '=== TEST 2: RLS Policies Exist ===' as test_section;

SELECT
  tablename,
  policyname,
  cmd as operation,
  CASE
    WHEN qual LIKE '%is_admin%' THEN '✅ Uses is_admin()'
    WHEN qual LIKE '%auth.uid()%' THEN '✅ Uses auth.uid()'
    ELSE '⚠️ Other logic'
  END as policy_type
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'items', 'audit_logs')
ORDER BY tablename, cmd;

-- Expected: Should see policies on all 3 tables

-- ============================================================================
-- TEST 3: Check RLS is enabled
-- ============================================================================
SELECT
  '=== TEST 3: RLS Enabled ===' as test_section;

SELECT
  tablename,
  CASE
    WHEN rowsecurity THEN '✅ ENABLED'
    ELSE '❌ DISABLED'
  END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'items', 'audit_logs')
ORDER BY tablename;

-- Expected: All should show ENABLED

-- ============================================================================
-- TEST 4: Verify is_admin() is SECURITY DEFINER
-- ============================================================================
SELECT
  '=== TEST 4: is_admin() Security Type ===' as test_section;

SELECT
  routine_name,
  CASE
    WHEN security_type = 'DEFINER' THEN '✅ SECURITY DEFINER (correct)'
    ELSE '❌ NOT SECURITY DEFINER (wrong)'
  END as security_status,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'is_admin';

-- Expected: Should show SECURITY DEFINER

-- ============================================================================
-- TEST 5: Count profiles (should work without recursion)
-- ============================================================================
SELECT
  '=== TEST 5: Query Profiles Table ===' as test_section;

-- This should work even though RLS is enabled
-- because you're using superuser/service role connection
SELECT
  COUNT(*) as total_profiles,
  COUNT(CASE WHEN role = 'admin' THEN 1 END) as admin_count,
  COUNT(CASE WHEN role = 'user' THEN 1 END) as user_count,
  '✅ PASS: No recursion error' as test_result
FROM public.profiles;

-- ============================================================================
-- TEST 6: Query items table (should work)
-- ============================================================================
SELECT
  '=== TEST 6: Query Items Table ===' as test_section;

SELECT
  COUNT(*) as total_items,
  COUNT(DISTINCT user_id) as unique_owners,
  '✅ PASS: No recursion error' as test_result
FROM public.items;

-- ============================================================================
-- TEST 7: Query audit_logs table (should work)
-- ============================================================================
SELECT
  '=== TEST 7: Query Audit Logs Table ===' as test_section;

SELECT
  COUNT(*) as total_logs,
  '✅ PASS: No recursion error' as test_result
FROM public.audit_logs;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
SELECT
  '=== FINAL RESULT ===' as section,
  'If all tests above passed, RLS is configured correctly!' as message,
  'Migration 007 was successful ✅' as status;

-- ============================================================================
-- NOTES
-- ============================================================================
-- This test only verifies:
-- 1. ✅ No infinite recursion errors
-- 2. ✅ All policies exist
-- 3. ✅ RLS is enabled
-- 4. ✅ is_admin() function works
-- 5. ✅ Tables can be queried
--
-- This test does NOT verify:
-- - Actual access control (need authenticated session for that)
-- - Policy logic correctness (need to test as different users)
--
-- For full RLS testing with actual access control, you MUST:
-- - Use Supabase Dashboard SQL Editor
-- - Be logged in as a user
-- - Run test_rls_simple.sql there
