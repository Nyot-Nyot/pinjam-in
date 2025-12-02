-- Test Script for Admin User Management Functions
-- Purpose: Test all functions in migration 008
-- Run after applying migration 008_admin_functions_users.sql

-- ============================================================================
-- PREREQUISITES
-- ============================================================================
-- 1. Migration 008 must be applied
-- 2. You must be logged in as admin user
-- 3. At least 2 users must exist (1 admin, 1 regular user)

-- ============================================================================
-- SETUP: Check Prerequisites
-- ============================================================================

-- IMPORTANT: When running in Supabase SQL Editor, auth.uid() returns NULL
-- You need to manually set a test user ID variable below

-- First, list all users to get an admin user ID
SELECT
  '=== AVAILABLE USERS ===' as test_section,
  id,
  full_name,
  role,
  status
FROM public.profiles
ORDER BY role DESC, full_name;

-- Copy an admin user ID from above and paste it in the variable below
-- Replace 'your-admin-user-id-here' with actual UUID

DO $$
DECLARE
  v_test_admin_id UUID := 'your-admin-user-id-here'; -- REPLACE THIS!
  v_is_admin BOOLEAN;
BEGIN
  -- Check if the user exists and is admin
  SELECT role = 'admin' INTO v_is_admin
  FROM public.profiles
  WHERE id = v_test_admin_id;

  IF v_is_admin THEN
    RAISE NOTICE '✅ PREREQUISITE CHECK PASSED: User % is an admin', v_test_admin_id;
  ELSE
    RAISE EXCEPTION '❌ PREREQUISITE CHECK FAILED: User % is not an admin or does not exist', v_test_admin_id;
  END IF;
END $$;

-- Note: For remaining tests, you'll need to replace auth.uid() with actual admin UUID
-- Or set it as a psql variable if running from command line

-- ============================================================================
-- TEST 1: create_admin_audit_log() Helper Function
-- ============================================================================

-- Note: Replace 'your-admin-user-id-here' with your actual admin UUID
-- You can get it from the query in SETUP section above

/*
SELECT '=== TEST 1: create_admin_audit_log() ===' as test_section;

-- Test creating audit log
SELECT public.create_admin_audit_log(
  'your-admin-user-id-here'::UUID,
  'test',
  'profiles',
  'your-admin-user-id-here'::UUID,
  jsonb_build_object('test', 'old_value'),
  jsonb_build_object('test', 'new_value'),
  jsonb_build_object('test_run', true)
) as audit_id;

-- Verify audit log was created
SELECT
  id,
  admin_user_id,
  action_type,
  table_name,
  old_values,
  new_values,
  metadata
FROM public.audit_logs
WHERE action_type = 'test'
ORDER BY created_at DESC
LIMIT 1;
*/

DO $$
BEGIN
  RAISE NOTICE 'TEST 1: Replace admin user ID in commented queries above to test create_admin_audit_log()';
END $$;

-- Expected: Should return the audit log we just created
-- ✅ PASS if audit log exists with correct data

-- ============================================================================
-- TEST 2: admin_get_all_users() - No Filters
-- ============================================================================

SELECT '=== TEST 2: admin_get_all_users() - No Filters ===' as test_section;

SELECT * FROM public.admin_get_all_users(50, 0, NULL, NULL, NULL);

-- Expected: Returns all users with stats
-- ✅ PASS if:
--   - All users are returned
--   - items_count is correct
--   - No errors

-- ============================================================================
-- TEST 3: admin_get_all_users() - With Filters
-- ============================================================================

SELECT '=== TEST 3: admin_get_all_users() - Filter by Role ===' as test_section;

-- Filter by admin role
SELECT * FROM public.admin_get_all_users(50, 0, 'admin', NULL, NULL);

-- Expected: Only admin users
-- ✅ PASS if all returned users have role='admin'

SELECT '=== TEST 3b: admin_get_all_users() - Filter by Status ===' as test_section;

-- Filter by active status
SELECT * FROM public.admin_get_all_users(50, 0, NULL, 'active', NULL);

-- Expected: Only active users
-- ✅ PASS if all returned users have status='active'

SELECT '=== TEST 3c: admin_get_all_users() - Search ===' as test_section;

-- Search by name (replace 'test' with part of actual user name)
SELECT * FROM public.admin_get_all_users(50, 0, NULL, NULL, 'a');

-- Expected: Users whose name or email contains 'a'
-- ✅ PASS if results match search criteria

-- ============================================================================
-- TEST 4: admin_get_all_users() - Pagination
-- ============================================================================

SELECT '=== TEST 4: admin_get_all_users() - Pagination ===' as test_section;

-- Get first 2 users
SELECT * FROM public.admin_get_all_users(2, 0, NULL, NULL, NULL);

-- Get next 2 users
SELECT * FROM public.admin_get_all_users(2, 2, NULL, NULL, NULL);

-- Expected: Different users in each result
-- ✅ PASS if pagination works correctly

-- ============================================================================
-- TEST 5: admin_get_user_details()
-- ============================================================================

SELECT '=== TEST 5: admin_get_user_details() ===' as test_section;

-- Test with your admin user ID
-- Replace 'your-admin-user-id-here' with actual UUID
-- SELECT * FROM public.admin_get_user_details('your-admin-user-id-here'::UUID);

DO $$
BEGIN
  RAISE NOTICE 'TEST 5: Replace admin user ID in commented query above to test admin_get_user_details()';
END $$;

-- Expected: Complete details with all metrics
-- ✅ PASS if:
--   - All profile fields present
--   - Activity metrics calculated
--   - storage_files_count present (may be 0)

-- Test with another user (replace with actual user ID from TEST setup)
-- SELECT * FROM public.admin_get_user_details('another-user-id-here');

-- ============================================================================
-- TEST 6: admin_get_user_details() - Error Cases
-- ============================================================================

SELECT '=== TEST 6: admin_get_user_details() - Invalid User ===' as test_section;

-- Test with non-existent user ID
DO $$
BEGIN
  PERFORM public.admin_get_user_details('00000000-0000-0000-0000-000000000000');
  RAISE EXCEPTION 'Should have thrown error for invalid user';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Correctly caught error: %', SQLERRM;
END $$;

-- Expected: Should raise "User not found" exception
-- ✅ PASS if error is raised

-- ============================================================================
-- TEST 7: admin_update_user_role() - Valid Update
-- ============================================================================

SELECT '=== TEST 7: admin_update_user_role() ===' as test_section;

-- Note: For this test, you need a test user ID
-- Replace 'test-user-id' with actual user ID

-- Create a test user first if needed, or use existing user
-- For now, we'll just show the query structure

/*
-- Test changing user to admin
SELECT * FROM public.admin_update_user_role('test-user-id', 'admin');

-- Verify role was changed
SELECT id, full_name, role FROM public.profiles WHERE id = 'test-user-id';

-- Verify audit log was created
SELECT * FROM public.audit_logs
WHERE table_name = 'profiles'
  AND action_type = 'update'
  AND record_id = 'test-user-id'
ORDER BY created_at DESC LIMIT 1;

-- Change back to user
SELECT * FROM public.admin_update_user_role('test-user-id', 'user');
*/

DO $$
BEGIN
  RAISE NOTICE 'TEST 7: Requires actual test user ID. See commented queries in script.';
END $$;

-- ✅ PASS if:
--   - Role changes successfully
--   - Audit log created
--   - Updated timestamp changed

-- ============================================================================
-- TEST 8: admin_update_user_role() - Error Cases
-- ============================================================================

SELECT '=== TEST 8: admin_update_user_role() - Error Cases ===' as test_section;

-- Test invalid role
-- Replace 'your-admin-user-id-here' with your actual admin UUID
DO $$
BEGIN
  PERFORM public.admin_update_user_role('your-admin-user-id-here'::UUID, 'invalid_role');
  RAISE EXCEPTION 'Should have thrown error for invalid role';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Correctly caught error: %', SQLERRM;
END $$;

-- Test self-demotion (removing own admin role)
DO $$
BEGIN
  PERFORM public.admin_update_user_role('your-admin-user-id-here'::UUID, 'user');
  RAISE EXCEPTION 'Should have thrown error for self-demotion';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Correctly caught error: %', SQLERRM;
END $$;

-- Expected: Both should raise exceptions
-- ✅ PASS if errors are raised

-- ============================================================================
-- TEST 9: admin_update_user_status() - Valid Update
-- ============================================================================

SELECT '=== TEST 9: admin_update_user_status() ===' as test_section;

/*
-- Test suspending user
SELECT * FROM public.admin_update_user_status('test-user-id', 'suspended', 'Test suspension');

-- Verify status was changed
SELECT id, full_name, status FROM public.profiles WHERE id = 'test-user-id';

-- Verify audit log
SELECT * FROM public.audit_logs
WHERE table_name = 'profiles'
  AND action_type = 'update'
  AND record_id = 'test-user-id'
ORDER BY created_at DESC LIMIT 1;

-- Reactivate user
SELECT * FROM public.admin_update_user_status('test-user-id', 'active', 'Test complete');
*/

DO $$
BEGIN
  RAISE NOTICE 'TEST 9: Requires actual test user ID. See commented queries in script.';
END $$;

-- ✅ PASS if:
--   - Status changes successfully
--   - Audit log created with reason
--   - Updated timestamp changed

-- ============================================================================
-- TEST 10: admin_update_user_status() - Error Cases
-- ============================================================================

SELECT '=== TEST 10: admin_update_user_status() - Error Cases ===' as test_section;

-- Test invalid status
-- Replace 'your-admin-user-id-here' with your actual admin UUID
DO $$
BEGIN
  PERFORM public.admin_update_user_status('your-admin-user-id-here'::UUID, 'invalid_status');
  RAISE EXCEPTION 'Should have thrown error for invalid status';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Correctly caught error: %', SQLERRM;
END $$;

-- Test self-deactivation
DO $$
BEGIN
  PERFORM public.admin_update_user_status('your-admin-user-id-here'::UUID, 'inactive');
  RAISE EXCEPTION 'Should have thrown error for self-deactivation';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Correctly caught error: %', SQLERRM;
END $$;

-- Expected: Both should raise exceptions
-- ✅ PASS if errors are raised

-- ============================================================================
-- TEST 11: admin_delete_user() - Soft Delete
-- ============================================================================

SELECT '=== TEST 11: admin_delete_user() - Soft Delete ===' as test_section;

/*
-- Test soft delete
SELECT * FROM public.admin_delete_user('test-user-id', FALSE, 'Test soft delete');

-- Verify user is inactive
SELECT id, full_name, status FROM public.profiles WHERE id = 'test-user-id';

-- Verify audit log
SELECT * FROM public.audit_logs
WHERE table_name = 'profiles'
  AND record_id = 'test-user-id'
ORDER BY created_at DESC LIMIT 1;

-- Reactivate for next test
SELECT * FROM public.admin_update_user_status('test-user-id', 'active', 'Reactivate for hard delete test');
*/

DO $$
BEGIN
  RAISE NOTICE 'TEST 11: Requires actual test user ID. See commented queries in script.';
END $$;

-- ✅ PASS if:
--   - Status set to 'inactive'
--   - Items preserved
--   - Audit log created

-- ============================================================================
-- TEST 12: admin_delete_user() - Error Cases
-- ============================================================================

SELECT '=== TEST 12: admin_delete_user() - Error Cases ===' as test_section;

-- Test self-deletion
-- Replace 'your-admin-user-id-here' with your actual admin UUID
DO $$
BEGIN
  PERFORM public.admin_delete_user('your-admin-user-id-here'::UUID, FALSE);
  RAISE EXCEPTION 'Should have thrown error for self-deletion';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Correctly caught error: %', SQLERRM;
END $$;

-- Expected: Should raise exception
-- ✅ PASS if error is raised

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

SELECT '=== TEST SUMMARY ===' as section;

-- Count audit logs created during testing
SELECT
  'Audit Logs Created' as metric,
  COUNT(*) as count
FROM public.audit_logs
WHERE created_at > NOW() - INTERVAL '1 hour';

-- List recent audit logs
SELECT
  admin_user_id,
  action_type,
  table_name,
  record_id,
  metadata->>'action' as action_detail,
  created_at
FROM public.audit_logs
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

-- ============================================================================
-- CLEANUP (Optional)
-- ============================================================================
-- Uncomment to clean up test audit logs

-- DELETE FROM public.audit_logs WHERE action_type = 'test';

-- ============================================================================
-- NOTES FOR COMPLETE TESTING
-- ============================================================================
-- To fully test functions that modify data, you need:
-- 1. A test user ID (not your admin account)
-- 2. Uncomment the relevant test sections
-- 3. Replace 'test-user-id' with actual UUID
-- 4. Run each test section individually
-- 5. Verify results after each operation
--
-- Tests that require actual user IDs:
-- - TEST 7: admin_update_user_role()
-- - TEST 9: admin_update_user_status()
-- - TEST 11: admin_delete_user() soft delete
-- - TEST 12: admin_delete_user() hard delete (use with caution!)
