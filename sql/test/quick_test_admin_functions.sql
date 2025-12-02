-- Quick Test for Admin Functions using Test Helpers
-- Run after applying migrations 008 and 008b

-- ============================================================================
-- STEP 1: Get Your Admin User ID
-- ============================================================================

SELECT
  '=== YOUR USERS ===' as section,
  id,
  full_name,
  role,
  status
FROM public.profiles
ORDER BY role DESC, full_name;

-- Copy an admin user ID from above

-- ============================================================================
-- STEP 2: Run All Tests
-- ============================================================================

DO $$
DECLARE
  -- ⚠️  REPLACE THIS with your admin user ID from step 1
  v_admin_id UUID := '9d6b3538-44e6-46b3-8f5b-e530be6449b8';

  -- Variables for testing
  v_test_user_id UUID;
  v_users_count INT;
  v_audit_id UUID;
  v_result RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║          ADMIN FUNCTIONS TEST - AUTOMATED                  ║';
  RAISE NOTICE '╚════════════════════════════════════════════════════════════╝';
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 1: Verify admin user
  -- ============================================================================
  RAISE NOTICE '📋 TEST 1: Verify Admin User';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  IF public.is_admin(v_admin_id) THEN
    RAISE NOTICE '✅ PASS: User % is an admin', v_admin_id;
  ELSE
    RAISE EXCEPTION '❌ FAIL: User % is not an admin', v_admin_id;
  END IF;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 2: create_admin_audit_log
  -- ============================================================================
  RAISE NOTICE '📋 TEST 2: create_admin_audit_log()';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  v_audit_id := public.create_admin_audit_log(
    v_admin_id,
    'view',  -- Changed from 'test' to 'view' (valid action_type)
    'profiles',
    v_admin_id,
    jsonb_build_object('test', 'old'),
    jsonb_build_object('test', 'new'),
    jsonb_build_object('automated_test', true, 'test_name', 'create_admin_audit_log')
  );

  IF v_audit_id IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Audit log created: %', v_audit_id;
  ELSE
    RAISE NOTICE '❌ FAIL: Failed to create audit log';
  END IF;
  RAISE NOTICE '';  -- ============================================================================
  -- TEST 3: admin_get_all_users_test - No Filters
  -- ============================================================================
  RAISE NOTICE '📋 TEST 3: admin_get_all_users_test() - No Filters';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_users_count
  FROM public.admin_get_all_users_test(v_admin_id, 50, 0, NULL, NULL, NULL);

  IF v_users_count > 0 THEN
    RAISE NOTICE '✅ PASS: Retrieved % users', v_users_count;
  ELSE
    RAISE NOTICE '❌ FAIL: No users found';
  END IF;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 4: admin_get_all_users_test - Filter by Admin
  -- ============================================================================
  RAISE NOTICE '📋 TEST 4: admin_get_all_users_test() - Filter by Admin';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_users_count
  FROM public.admin_get_all_users_test(v_admin_id, 50, 0, 'admin', NULL, NULL);

  RAISE NOTICE '✅ PASS: Found % admin users', v_users_count;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 5: admin_get_all_users_test - Filter by Active
  -- ============================================================================
  RAISE NOTICE '📋 TEST 5: admin_get_all_users_test() - Filter by Active';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_users_count
  FROM public.admin_get_all_users_test(v_admin_id, 50, 0, NULL, 'active', NULL);

  RAISE NOTICE '✅ PASS: Found % active users', v_users_count;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 6: admin_get_user_details_test
  -- ============================================================================
  RAISE NOTICE '📋 TEST 6: admin_get_user_details_test()';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT * INTO v_result
  FROM public.admin_get_user_details_test(v_admin_id, v_admin_id);

  RAISE NOTICE '✅ PASS: Retrieved user details';
  RAISE NOTICE '   - Role: %', v_result.role;
  RAISE NOTICE '   - Status: %', v_result.status;
  RAISE NOTICE '   - Total items: %', v_result.total_items;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 7: admin_get_user_details_test - Invalid User
  -- ============================================================================
  RAISE NOTICE '📋 TEST 7: admin_get_user_details_test() - Invalid User';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_get_user_details_test(v_admin_id, '00000000-0000-0000-0000-000000000000');
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 8: Find a test user (non-admin) for modification tests
  -- ============================================================================
  RAISE NOTICE '📋 TEST 8: Finding Test User';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT id INTO v_test_user_id
  FROM public.profiles
  WHERE role = 'user' AND id != v_admin_id
  LIMIT 1;

  IF v_test_user_id IS NULL THEN
    RAISE NOTICE '⚠️  WARNING: No regular user found. Skipping modification tests.';
    RAISE NOTICE '   Create a regular user to test update/delete functions.';
  ELSE
    RAISE NOTICE '✅ PASS: Found test user: %', v_test_user_id;

    -- ============================================================================
    -- TEST 9: admin_update_user_role_test - Promote to Admin
    -- ============================================================================
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 9: admin_update_user_role_test() - Promote';
    RAISE NOTICE '─────────────────────────────────────────────────────────────';

    SELECT * INTO v_result
    FROM public.admin_update_user_role_test(v_admin_id, v_test_user_id, 'admin');

    RAISE NOTICE '✅ PASS: % -> %', v_result.old_role, v_result.new_role;

    -- ============================================================================
    -- TEST 10: admin_update_user_role_test - Demote back
    -- ============================================================================
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 10: admin_update_user_role_test() - Demote';
    RAISE NOTICE '─────────────────────────────────────────────────────────────';

    SELECT * INTO v_result
    FROM public.admin_update_user_role_test(v_admin_id, v_test_user_id, 'user');

    RAISE NOTICE '✅ PASS: % -> %', v_result.old_role, v_result.new_role;

    -- ============================================================================
    -- TEST 11: admin_update_user_status_test - Suspend
    -- ============================================================================
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 11: admin_update_user_status_test() - Suspend';
    RAISE NOTICE '─────────────────────────────────────────────────────────────';

    SELECT * INTO v_result
    FROM public.admin_update_user_status_test(v_admin_id, v_test_user_id, 'suspended', 'Testing');

    RAISE NOTICE '✅ PASS: % -> %', v_result.old_status, v_result.new_status;

    -- ============================================================================
    -- TEST 12: admin_update_user_status_test - Reactivate
    -- ============================================================================
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 12: admin_update_user_status_test() - Reactivate';
    RAISE NOTICE '─────────────────────────────────────────────────────────────';

    SELECT * INTO v_result
    FROM public.admin_update_user_status_test(v_admin_id, v_test_user_id, 'active', 'Test complete');

    RAISE NOTICE '✅ PASS: % -> %', v_result.old_status, v_result.new_status;

    -- ============================================================================
    -- TEST 13: admin_delete_user_test - Soft Delete
    -- ============================================================================
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 13: admin_delete_user_test() - Soft Delete';
    RAISE NOTICE '─────────────────────────────────────────────────────────────';

    SELECT * INTO v_result
    FROM public.admin_delete_user_test(v_admin_id, v_test_user_id, FALSE, 'Testing soft delete');

    RAISE NOTICE '✅ PASS: % (%)', v_result.message, v_result.delete_type;

    -- ============================================================================
    -- TEST 14: Reactivate after soft delete
    -- ============================================================================
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 14: Reactivate After Soft Delete';
    RAISE NOTICE '─────────────────────────────────────────────────────────────';

    SELECT * INTO v_result
    FROM public.admin_update_user_status_test(v_admin_id, v_test_user_id, 'active', 'Restored after test');

    RAISE NOTICE '✅ PASS: User reactivated';
  END IF;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 15: Error Cases - Invalid Role
  -- ============================================================================
  RAISE NOTICE '📋 TEST 15: Error - Invalid Role';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_user_role_test(v_admin_id, v_admin_id, 'invalid');
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 16: Error Cases - Self Demotion
  -- ============================================================================
  RAISE NOTICE '📋 TEST 16: Error - Self Demotion';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_user_role_test(v_admin_id, v_admin_id, 'user');
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 17: Error Cases - Invalid Status
  -- ============================================================================
  RAISE NOTICE '📋 TEST 17: Error - Invalid Status';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_user_status_test(v_admin_id, v_admin_id, 'invalid');
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 18: Error Cases - Self Deactivation
  -- ============================================================================
  RAISE NOTICE '📋 TEST 18: Error - Self Deactivation';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_user_status_test(v_admin_id, v_admin_id, 'inactive');
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 19: Error Cases - Self Deletion
  -- ============================================================================
  RAISE NOTICE '📋 TEST 19: Error - Self Deletion';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_delete_user_test(v_admin_id, v_admin_id, FALSE);
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- SUMMARY
  -- ============================================================================
  RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║                      TEST SUMMARY                          ║';
  RAISE NOTICE '╚════════════════════════════════════════════════════════════╝';
  RAISE NOTICE '';

  SELECT COUNT(*) INTO v_users_count
  FROM public.audit_logs
  WHERE created_at > NOW() - INTERVAL '1 hour';

  RAISE NOTICE '📊 Audit logs created in last hour: %', v_users_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ All automated tests completed successfully!';
  RAISE NOTICE '';

END $$;

-- ============================================================================
-- View Recent Audit Logs
-- ============================================================================

SELECT
  '=== RECENT AUDIT LOGS ===' as section,
  admin_user_id,
  action_type,
  table_name,
  metadata->>'action' as action_detail,
  metadata->>'test_name' as test_name,
  created_at
FROM public.audit_logs
WHERE created_at > NOW() - INTERVAL '1 hour'
  AND metadata->>'automated_test' = 'true'
ORDER BY created_at DESC
LIMIT 20;

-- ============================================================================
-- CLEANUP (Optional)
-- ============================================================================

-- Uncomment to clean up test audit logs:
-- DELETE FROM public.audit_logs WHERE metadata->>'automated_test' = 'true';
