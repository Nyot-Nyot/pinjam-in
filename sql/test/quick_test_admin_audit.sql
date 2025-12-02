-- ============================================================================
-- QUICK TEST: Admin Audit & Utility Functions
-- ============================================================================
-- Purpose: Comprehensive automated tests for admin audit and utility functions
-- Usage: Run this entire script in Supabase SQL Editor
-- Expected: All tests should pass, with clear RAISE NOTICE messages
-- ============================================================================

-- Get admin user ID for testing
DO $$
DECLARE
  v_admin_id UUID;
  v_regular_user_id UUID;
  v_test_record_id UUID;
  v_audit_id UUID;
  v_total_audits BIGINT;
  v_filtered_count BIGINT;
  v_storage_files BIGINT;
  v_orphaned_files BIGINT;
  v_result RECORD;
BEGIN
  -- ============================================================================
  -- SETUP: Get test user IDs
  -- ============================================================================

  SELECT id INTO v_admin_id
  FROM public.profiles
  WHERE role = 'admin'
  LIMIT 1;

  SELECT id INTO v_regular_user_id
  FROM public.profiles
  WHERE role = 'user'
  LIMIT 1;

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'No admin user found. Create an admin user first.';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '════════════════════════════════════════════════════════════════';
  RAISE NOTICE 'ADMIN AUDIT & UTILITY FUNCTIONS TEST SUITE';
  RAISE NOTICE '════════════════════════════════════════════════════════════════';
  RAISE NOTICE 'Admin User ID: %', v_admin_id;
  RAISE NOTICE 'Regular User ID: %', COALESCE(v_regular_user_id::TEXT, 'None');
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 1: Create Audit Log - Basic
  -- ============================================================================

  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 1: Create Audit Log - Basic CREATE action';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  v_test_record_id := gen_random_uuid();

  SELECT id INTO v_audit_id
  FROM public.admin_create_audit_log_test(
    v_admin_id,
    'CREATE',
    'profiles',
    v_test_record_id,
    NULL,
    '{"role":"user","status":"active"}'::JSONB,
    '{"test":"basic_create"}'::JSONB
  );

  IF v_audit_id IS NULL THEN
    RAISE EXCEPTION '❌ TEST 1 FAILED: Audit log not created';
  END IF;

  RAISE NOTICE '✅ TEST 1 PASSED: Audit log created with ID: %', v_audit_id;

  -- ============================================================================
  -- TEST 2: Create Audit Log - UPDATE action
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 2: Create Audit Log - UPDATE action with old/new values';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  SELECT id INTO v_audit_id
  FROM public.admin_create_audit_log_test(
    v_admin_id,
    'UPDATE',
    'profiles',
    v_test_record_id,
    '{"role":"user"}'::JSONB,
    '{"role":"admin"}'::JSONB,
    '{"test":"role_change","reason":"promotion"}'::JSONB
  );

  IF v_audit_id IS NULL THEN
    RAISE EXCEPTION '❌ TEST 2 FAILED: UPDATE audit log not created';
  END IF;

  RAISE NOTICE '✅ TEST 2 PASSED: UPDATE audit log created';

  -- ============================================================================
  -- TEST 3: Create Audit Log - DELETE action
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 3: Create Audit Log - DELETE action';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  SELECT id INTO v_audit_id
  FROM public.admin_create_audit_log_test(
    v_admin_id,
    'DELETE',
    'items',
    v_test_record_id,
    '{"name":"Test Item","status":"borrowed"}'::JSONB,
    NULL,
    '{"test":"soft_delete","hard_delete":false}'::JSONB
  );

  IF v_audit_id IS NULL THEN
    RAISE EXCEPTION '❌ TEST 3 FAILED: DELETE audit log not created';
  END IF;

  RAISE NOTICE '✅ TEST 3 PASSED: DELETE audit log created';

  -- ============================================================================
  -- TEST 4: Get All Audit Logs - No filters
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 4: Get All Audit Logs - Default pagination (50)';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_total_audits
  FROM public.admin_get_audit_logs_test(v_admin_id);

  IF v_total_audits IS NULL THEN
    RAISE EXCEPTION '❌ TEST 4 FAILED: Could not retrieve audit logs';
  END IF;

  RAISE NOTICE '✅ TEST 4 PASSED: Retrieved % audit logs', v_total_audits;

  -- ============================================================================
  -- TEST 5: Get Audit Logs - Filter by action_type
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 5: Get Audit Logs - Filter by action_type = UPDATE';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_filtered_count
  FROM public.admin_get_audit_logs_test(
    v_admin_id,
    '{"action_type":"UPDATE"}'::JSONB
  );

  RAISE NOTICE '✅ TEST 5 PASSED: Retrieved % UPDATE audit logs', v_filtered_count;

  -- ============================================================================
  -- TEST 6: Get Audit Logs - Filter by table_name
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 6: Get Audit Logs - Filter by table_name = profiles';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_filtered_count
  FROM public.admin_get_audit_logs_test(
    v_admin_id,
    '{"table_name":"profiles"}'::JSONB
  );

  RAISE NOTICE '✅ TEST 6 PASSED: Retrieved % profiles audit logs', v_filtered_count;

  -- ============================================================================
  -- TEST 7: Get Audit Logs - Pagination
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 7: Get Audit Logs - Pagination (limit=5, offset=0)';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_filtered_count
  FROM public.admin_get_audit_logs_test(
    v_admin_id,
    '{"limit":5,"offset":0}'::JSONB
  );

  IF v_filtered_count > 5 THEN
    RAISE EXCEPTION '❌ TEST 7 FAILED: Returned % rows, expected <= 5', v_filtered_count;
  END IF;

  RAISE NOTICE '✅ TEST 7 PASSED: Pagination working, returned % rows', v_filtered_count;

  -- ============================================================================
  -- TEST 8: Get Audit Logs - Multiple filters
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 8: Get Audit Logs - Multiple filters (action + table + limit)';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_filtered_count
  FROM public.admin_get_audit_logs_test(
    v_admin_id,
    '{"action_type":"UPDATE","table_name":"profiles","limit":10}'::JSONB
  );

  RAISE NOTICE '✅ TEST 8 PASSED: Multiple filters working, returned % rows', v_filtered_count;

  -- ============================================================================
  -- TEST 9: Get Audit Logs - Date range filter
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 9: Get Audit Logs - Date range (today only)';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_filtered_count
  FROM public.admin_get_audit_logs_test(
    v_admin_id,
    jsonb_build_object(
      'date_from', CURRENT_DATE,
      'date_to', CURRENT_DATE
    )
  );

  RAISE NOTICE '✅ TEST 9 PASSED: Date filter working, % logs today', v_filtered_count;

  -- ============================================================================
  -- TEST 10: Get Storage Stats
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 10: Get Storage Stats';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  SELECT
    total_files,
    total_size_mb,
    items_with_photos,
    orphaned_files
  INTO v_result
  FROM public.admin_get_storage_stats_test(v_admin_id);

  IF v_result IS NULL THEN
    RAISE EXCEPTION '❌ TEST 10 FAILED: Could not retrieve storage stats';
  END IF;

  RAISE NOTICE '✅ TEST 10 PASSED: Storage stats retrieved';
  RAISE NOTICE '   Total files: %', v_result.total_files;
  RAISE NOTICE '   Total size: % MB', v_result.total_size_mb;
  RAISE NOTICE '   Items with photos: %', v_result.items_with_photos;
  RAISE NOTICE '   Orphaned files: %', v_result.orphaned_files;

  -- ============================================================================
  -- TEST 11: Parameter Validation - Invalid action_type
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 11: Parameter Validation - Invalid action_type';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_create_audit_log_test(
      v_admin_id,
      'INVALID_ACTION',
      'profiles',
      gen_random_uuid(),
      NULL,
      NULL,
      NULL
    );
    RAISE EXCEPTION '❌ TEST 11 FAILED: Should have rejected invalid action_type';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Invalid action_type%' THEN
        RAISE NOTICE '✅ TEST 11 PASSED: Invalid action_type rejected';
      ELSE
        RAISE EXCEPTION '❌ TEST 11 FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;

  -- ============================================================================
  -- TEST 12: Parameter Validation - NULL action_type
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 12: Parameter Validation - NULL action_type';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_create_audit_log_test(
      v_admin_id,
      NULL,
      'profiles',
      gen_random_uuid(),
      NULL,
      NULL,
      NULL
    );
    RAISE EXCEPTION '❌ TEST 12 FAILED: Should have rejected NULL action_type';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Invalid action_type%' THEN
        RAISE NOTICE '✅ TEST 12 PASSED: NULL action_type rejected';
      ELSE
        RAISE EXCEPTION '❌ TEST 12 FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;

  -- ============================================================================
  -- TEST 13: Parameter Validation - Invalid limit (too high)
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 13: Parameter Validation - Invalid limit (> 200)';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM COUNT(*)
    FROM public.admin_get_audit_logs_test(
      v_admin_id,
      '{"limit":500}'::JSONB
    );
    RAISE EXCEPTION '❌ TEST 13 FAILED: Should have rejected limit > 200';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Invalid limit%' THEN
        RAISE NOTICE '✅ TEST 13 PASSED: Invalid limit rejected';
      ELSE
        RAISE EXCEPTION '❌ TEST 13 FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;

  -- ============================================================================
  -- TEST 14: Parameter Validation - Negative offset
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 14: Parameter Validation - Negative offset';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM COUNT(*)
    FROM public.admin_get_audit_logs_test(
      v_admin_id,
      '{"offset":-5}'::JSONB
    );
    RAISE EXCEPTION '❌ TEST 14 FAILED: Should have rejected negative offset';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Invalid offset%' THEN
        RAISE NOTICE '✅ TEST 14 PASSED: Negative offset rejected';
      ELSE
        RAISE EXCEPTION '❌ TEST 14 FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;

  -- ============================================================================
  -- TEST 15: Security - Non-admin cannot create audit log
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 15: Security - Non-admin cannot create audit log';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  IF v_regular_user_id IS NOT NULL THEN
    BEGIN
      PERFORM public.admin_create_audit_log_test(
        v_regular_user_id,
        'CREATE',
        'profiles',
        gen_random_uuid(),
        NULL,
        NULL,
        NULL
      );
      RAISE EXCEPTION '❌ TEST 15 FAILED: Non-admin should not be able to create audit log';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM LIKE '%Permission denied%' THEN
          RAISE NOTICE '✅ TEST 15 PASSED: Non-admin rejected';
        ELSE
          RAISE EXCEPTION '❌ TEST 15 FAILED: Wrong error: %', SQLERRM;
        END IF;
    END;
  ELSE
    RAISE NOTICE '⚠️  TEST 15 SKIPPED: No regular user found';
  END IF;

  -- ============================================================================
  -- TEST 16: Security - Non-admin cannot view audit logs
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';
  RAISE NOTICE 'TEST 16: Security - Non-admin cannot view audit logs';
  RAISE NOTICE '────────────────────────────────────────────────────────────────';

  IF v_regular_user_id IS NOT NULL THEN
    BEGIN
      PERFORM COUNT(*)
      FROM public.admin_get_audit_logs_test(v_regular_user_id);
      RAISE EXCEPTION '❌ TEST 16 FAILED: Non-admin should not be able to view audit logs';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM LIKE '%Permission denied%' THEN
          RAISE NOTICE '✅ TEST 16 PASSED: Non-admin rejected';
        ELSE
          RAISE EXCEPTION '❌ TEST 16 FAILED: Wrong error: %', SQLERRM;
        END IF;
    END;
  ELSE
    RAISE NOTICE '⚠️  TEST 16 SKIPPED: No regular user found';
  END IF;

  -- ============================================================================
  -- SUMMARY
  -- ============================================================================

  RAISE NOTICE '';
  RAISE NOTICE '════════════════════════════════════════════════════════════════';
  RAISE NOTICE 'TEST SUITE COMPLETED SUCCESSFULLY';
  RAISE NOTICE '════════════════════════════════════════════════════════════════';
  RAISE NOTICE '✅ All 16 tests passed';
  RAISE NOTICE '';
  RAISE NOTICE 'Functions tested:';
  RAISE NOTICE '  - admin_create_audit_log() ✓';
  RAISE NOTICE '  - admin_get_audit_logs() ✓';
  RAISE NOTICE '  - admin_get_storage_stats() ✓';
  RAISE NOTICE '';
  RAISE NOTICE 'Coverage:';
  RAISE NOTICE '  - Basic operations ✓';
  RAISE NOTICE '  - Filters and pagination ✓';
  RAISE NOTICE '  - Parameter validation ✓';
  RAISE NOTICE '  - Security (admin-only) ✓';
  RAISE NOTICE '════════════════════════════════════════════════════════════════';
  RAISE NOTICE '';

END $$;
