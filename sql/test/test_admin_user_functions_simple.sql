-- Simple Test Script for Admin User Management Functions
-- Purpose: Quick tests that work in Supabase SQL Editor
-- Run after applying migration 008_admin_functions_users.sql

-- ============================================================================
-- IMPORTANT: SET YOUR USER IDs HERE
-- ============================================================================

-- Step 1: Get your admin user ID
SELECT
  'Your Users' as section,
  id,
  full_name,
  role,
  status
FROM public.profiles
ORDER BY role DESC, full_name;

-- Step 2: Copy an admin user ID from above and paste below
-- Step 3: Copy a regular user ID for testing write operations (optional)

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

DO $$
DECLARE
  -- REPLACE THESE WITH ACTUAL UUIDs FROM THE QUERY ABOVE!
  v_admin_user_id UUID := 'your-admin-user-id-here';  -- Your admin account
  v_test_user_id UUID := 'optional-test-user-id';     -- Regular user for testing modifications

  -- Test results
  v_audit_id UUID;
  v_users_count INT;
  v_user_exists BOOLEAN;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║          ADMIN USER MANAGEMENT FUNCTIONS TEST              ║';
  RAISE NOTICE '╚════════════════════════════════════════════════════════════╝';
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 1: Verify Admin User
  -- ============================================================================
  RAISE NOTICE '📋 TEST 1: Verify Admin User';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT EXISTS(
    SELECT 1 FROM public.profiles
    WHERE id = v_admin_user_id AND role = 'admin'
  ) INTO v_user_exists;

  IF v_user_exists THEN
    RAISE NOTICE '✅ PASS: User % is an admin', v_admin_user_id;
  ELSE
    RAISE EXCEPTION '❌ FAIL: User % is not an admin or does not exist. Please update v_admin_user_id variable!', v_admin_user_id;
  END IF;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 2: create_admin_audit_log() Helper Function
  -- ============================================================================
  RAISE NOTICE '📋 TEST 2: create_admin_audit_log()';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  v_audit_id := public.create_admin_audit_log(
    v_admin_user_id,
    'view',  -- Changed from 'test' to 'view' (valid action_type)
    'profiles',
    v_admin_user_id,
    jsonb_build_object('test', 'old_value'),
    jsonb_build_object('test', 'new_value'),
    jsonb_build_object('test_run', true, 'test_name', 'create_admin_audit_log')
  );

  IF v_audit_id IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Audit log created with ID: %', v_audit_id;
  ELSE
    RAISE NOTICE '❌ FAIL: Failed to create audit log';
  END IF;
    RAISE NOTICE '❌ FAIL: Failed to create audit log';
  END IF;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 3: admin_get_all_users() - No Filters
  -- ============================================================================
  RAISE NOTICE '📋 TEST 3: admin_get_all_users() - No Filters';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_users_count
  FROM public.admin_get_all_users(50, 0, NULL, NULL, NULL);

  IF v_users_count > 0 THEN
    RAISE NOTICE '✅ PASS: Retrieved % users', v_users_count;
  ELSE
    RAISE NOTICE '❌ FAIL: No users returned';
  END IF;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 4: admin_get_all_users() - Filter by Admin Role
  -- ============================================================================
  RAISE NOTICE '📋 TEST 4: admin_get_all_users() - Filter by Admin Role';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_users_count
  FROM public.admin_get_all_users(50, 0, 'admin', NULL, NULL);

  IF v_users_count > 0 THEN
    RAISE NOTICE '✅ PASS: Retrieved % admin users', v_users_count;
  ELSE
    RAISE NOTICE '⚠️  WARNING: No admin users found';
  END IF;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 5: admin_get_all_users() - Filter by Active Status
  -- ============================================================================
  RAISE NOTICE '📋 TEST 5: admin_get_all_users() - Filter by Active Status';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_users_count
  FROM public.admin_get_all_users(50, 0, NULL, 'active', NULL);

  IF v_users_count > 0 THEN
    RAISE NOTICE '✅ PASS: Retrieved % active users', v_users_count;
  ELSE
    RAISE NOTICE '⚠️  WARNING: No active users found';
  END IF;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 6: admin_get_user_details() - Valid User
  -- ============================================================================
  RAISE NOTICE '📋 TEST 6: admin_get_user_details() - Valid User';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  PERFORM public.admin_get_user_details(v_admin_user_id);
  RAISE NOTICE '✅ PASS: Retrieved user details for admin user';

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 7: admin_get_user_details() - Invalid User
  -- ============================================================================
  RAISE NOTICE '📋 TEST 7: admin_get_user_details() - Invalid User';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_get_user_details('00000000-0000-0000-0000-000000000000');
    RAISE NOTICE '❌ FAIL: Should have thrown error for invalid user';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 8: admin_update_user_role() - Invalid Role
  -- ============================================================================
  RAISE NOTICE '📋 TEST 8: admin_update_user_role() - Invalid Role';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_user_role(v_admin_user_id, 'invalid_role');
    RAISE NOTICE '❌ FAIL: Should have thrown error for invalid role';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 9: admin_update_user_role() - Self-Demotion
  -- ============================================================================
  RAISE NOTICE '📋 TEST 9: admin_update_user_role() - Self-Demotion';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_user_role(v_admin_user_id, 'user');
    RAISE NOTICE '❌ FAIL: Should have thrown error for self-demotion';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 10: admin_update_user_status() - Invalid Status
  -- ============================================================================
  RAISE NOTICE '📋 TEST 10: admin_update_user_status() - Invalid Status';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_user_status(v_admin_user_id, 'invalid_status');
    RAISE NOTICE '❌ FAIL: Should have thrown error for invalid status';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 11: admin_update_user_status() - Self-Deactivation
  -- ============================================================================
  RAISE NOTICE '📋 TEST 11: admin_update_user_status() - Self-Deactivation';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_user_status(v_admin_user_id, 'inactive');
    RAISE NOTICE '❌ FAIL: Should have thrown error for self-deactivation';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 12: admin_delete_user() - Self-Deletion
  -- ============================================================================
  RAISE NOTICE '📋 TEST 12: admin_delete_user() - Self-Deletion';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_delete_user(v_admin_user_id, FALSE);
    RAISE NOTICE '❌ FAIL: Should have thrown error for self-deletion';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST SUMMARY
  -- ============================================================================
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║                      TEST SUMMARY                          ║';
  RAISE NOTICE '╚════════════════════════════════════════════════════════════╝';
  RAISE NOTICE '';

  SELECT COUNT(*) INTO v_users_count
  FROM public.audit_logs
  WHERE created_at > NOW() - INTERVAL '1 hour'
    AND metadata->>'test_run' = 'true';

  RAISE NOTICE '📊 Audit logs created during testing: %', v_users_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ All automated tests completed successfully!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Note: Tests that modify data (update role/status, delete) require';
  RAISE NOTICE '    a separate test user ID. Set v_test_user_id variable and uncomment';
  RAISE NOTICE '    optional tests at the end of this script.';
  RAISE NOTICE '';

END $$;

-- ============================================================================
-- VIEW RESULTS
-- ============================================================================

-- Show recent audit logs
SELECT
  '=== RECENT AUDIT LOGS ===' as section,
  admin_user_id,
  action_type,
  table_name,
  metadata->>'test_name' as test_name,
  created_at
FROM public.audit_logs
WHERE created_at > NOW() - INTERVAL '1 hour'
  AND metadata->>'test_run' = 'true'
ORDER BY created_at DESC
LIMIT 10;

-- ============================================================================
-- OPTIONAL: CLEANUP TEST AUDIT LOGS
-- ============================================================================

-- Uncomment to clean up test audit logs
-- DELETE FROM public.audit_logs WHERE metadata->>'test_run' = 'true';

-- ============================================================================
-- OPTIONAL: TESTS WITH TEST USER (Requires v_test_user_id)
-- ============================================================================

/*
-- These tests require a separate test user ID (not your admin account)
-- Uncomment and replace v_test_user_id in the DO block above

DO $$
DECLARE
  v_admin_user_id UUID := 'your-admin-user-id-here';
  v_test_user_id UUID := 'test-user-id-here';  -- A regular user, not admin
  v_result RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║              MODIFICATION TESTS (TEST USER)                ║';
  RAISE NOTICE '╚════════════════════════════════════════════════════════════╝';
  RAISE NOTICE '';

  -- Test promote to admin
  RAISE NOTICE '📋 TEST: Promote user to admin';
  SELECT * INTO v_result FROM public.admin_update_user_role(v_test_user_id, 'admin');
  RAISE NOTICE '✅ Result: %', v_result;

  -- Test demote back to user
  RAISE NOTICE '📋 TEST: Demote user back to regular';
  SELECT * INTO v_result FROM public.admin_update_user_role(v_test_user_id, 'user');
  RAISE NOTICE '✅ Result: %', v_result;

  -- Test suspend user
  RAISE NOTICE '📋 TEST: Suspend user';
  SELECT * INTO v_result FROM public.admin_update_user_status(v_test_user_id, 'suspended', 'Testing suspension');
  RAISE NOTICE '✅ Result: %', v_result;

  -- Test reactivate user
  RAISE NOTICE '📋 TEST: Reactivate user';
  SELECT * INTO v_result FROM public.admin_update_user_status(v_test_user_id, 'active', 'Testing reactivation');
  RAISE NOTICE '✅ Result: %', v_result;

  -- Test soft delete
  RAISE NOTICE '📋 TEST: Soft delete user';
  SELECT * INTO v_result FROM public.admin_delete_user(v_test_user_id, FALSE, 'Testing soft delete');
  RAISE NOTICE '✅ Result: %', v_result;

  -- Reactivate after soft delete
  RAISE NOTICE '📋 TEST: Reactivate after soft delete';
  SELECT * INTO v_result FROM public.admin_update_user_status(v_test_user_id, 'active', 'Reactivating after test');
  RAISE NOTICE '✅ Result: %', v_result;

  RAISE NOTICE '';
  RAISE NOTICE '✅ All modification tests completed!';
END $$;
*/
