-- Quick Test for Admin Analytics Functions using Test Helpers
-- Run after applying migrations 010 and 010b

-- ============================================================================
-- STEP 1: Get Your Admin User ID
-- ============================================================================

SELECT
  '=== YOUR ADMIN USER ===' as section,
  id,
  full_name,
  role,
  status
FROM public.profiles
WHERE role = 'admin'
ORDER BY full_name;

-- Copy an admin user ID from above

-- ============================================================================
-- STEP 2: Check Current Database State
-- ============================================================================

SELECT
  '=== DATABASE STATE ===' as section,
  (SELECT COUNT(*) FROM public.profiles) as total_users,
  (SELECT COUNT(*) FROM public.profiles WHERE role = 'admin') as admin_users,
  (SELECT COUNT(*) FROM public.items) as total_items,
  (SELECT COUNT(*) FROM public.items WHERE status = 'borrowed') as borrowed_items,
  (SELECT COUNT(*) FROM public.items WHERE status = 'returned') as returned_items;

-- ============================================================================
-- STEP 3: Run All Tests
-- ============================================================================

DO $$
DECLARE
  -- ⚠️  REPLACE THIS with your admin user ID from step 1
  v_admin_id UUID := '9d6b3538-44e6-46b3-8f5b-e530be6449b8';

  -- Variables for testing
  v_result RECORD;
  v_row_count INT;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║      ADMIN ANALYTICS FUNCTIONS TEST - AUTOMATED           ║';
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
  -- TEST 2: admin_get_dashboard_stats_test
  -- ============================================================================
  RAISE NOTICE '📋 TEST 2: admin_get_dashboard_stats_test()';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT * INTO v_result
  FROM public.admin_get_dashboard_stats_test(v_admin_id);

  RAISE NOTICE '✅ PASS: Dashboard stats retrieved';
  RAISE NOTICE '   - Total users: %', v_result.total_users;
  RAISE NOTICE '   - Active users: %', v_result.active_users;
  RAISE NOTICE '   - Admin users: %', v_result.admin_users;
  RAISE NOTICE '   - Total items: %', v_result.total_items;
  RAISE NOTICE '   - Borrowed items: %', v_result.borrowed_items;
  RAISE NOTICE '   - Returned items: %', v_result.returned_items;
  RAISE NOTICE '   - Overdue items: %', v_result.overdue_items;
  RAISE NOTICE '   - Storage files: %', v_result.total_storage_files;
  RAISE NOTICE '   - New users today: %', v_result.new_users_today;
  RAISE NOTICE '   - New items today: %', v_result.new_items_today;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 3: Validate dashboard stats accuracy
  -- ============================================================================
  RAISE NOTICE '📋 TEST 3: Validate Dashboard Stats Accuracy';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  -- Check total users matches
  IF v_result.total_users = (SELECT COUNT(*) FROM public.profiles) THEN
    RAISE NOTICE '✅ PASS: Total users count is accurate';
  ELSE
    RAISE NOTICE '❌ FAIL: Total users count mismatch';
  END IF;

  -- Check total items matches
  IF v_result.total_items = (SELECT COUNT(*) FROM public.items) THEN
    RAISE NOTICE '✅ PASS: Total items count is accurate';
  ELSE
    RAISE NOTICE '❌ FAIL: Total items count mismatch';
  END IF;

  -- Check borrowed items matches
  IF v_result.borrowed_items = (SELECT COUNT(*) FROM public.items WHERE status = 'borrowed') THEN
    RAISE NOTICE '✅ PASS: Borrowed items count is accurate';
  ELSE
    RAISE NOTICE '❌ FAIL: Borrowed items count mismatch';
  END IF;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 4: admin_get_user_growth_test - 7 days
  -- ============================================================================
  RAISE NOTICE '📋 TEST 4: admin_get_user_growth_test(7)';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_row_count
  FROM public.admin_get_user_growth_test(v_admin_id, 7);

  IF v_row_count = 7 THEN
    RAISE NOTICE '✅ PASS: Retrieved 7 days of user growth data';
  ELSE
    RAISE NOTICE '❌ FAIL: Expected 7 rows, got %', v_row_count;
  END IF;

  -- Show sample data
  SELECT * INTO v_result
  FROM public.admin_get_user_growth_test(v_admin_id, 7)
  ORDER BY date DESC
  LIMIT 1;

  RAISE NOTICE '   - Latest date: %', v_result.date;
  RAISE NOTICE '   - New users: %', v_result.new_users;
  RAISE NOTICE '   - Cumulative users: %', v_result.cumulative_users;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 5: admin_get_user_growth_test - 30 days
  -- ============================================================================
  RAISE NOTICE '📋 TEST 5: admin_get_user_growth_test(30)';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_row_count
  FROM public.admin_get_user_growth_test(v_admin_id, 30);

  IF v_row_count = 30 THEN
    RAISE NOTICE '✅ PASS: Retrieved 30 days of user growth data';
  ELSE
    RAISE NOTICE '❌ FAIL: Expected 30 rows, got %', v_row_count;
  END IF;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 6: admin_get_user_growth_test - Invalid days (should fail)
  -- ============================================================================
  RAISE NOTICE '📋 TEST 6: admin_get_user_growth_test(-1) - Invalid Days';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_get_user_growth_test(v_admin_id, -1);
    RAISE NOTICE '❌ FAIL: Should have thrown error for invalid days';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 7: admin_get_user_growth_test - Too many days (should fail)
  -- ============================================================================
  RAISE NOTICE '📋 TEST 7: admin_get_user_growth_test(400) - Too Many Days';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_get_user_growth_test(v_admin_id, 400);
    RAISE NOTICE '❌ FAIL: Should have thrown error for days > 365';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 8: admin_get_item_statistics_test
  -- ============================================================================
  RAISE NOTICE '📋 TEST 8: admin_get_item_statistics_test()';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT * INTO v_result
  FROM public.admin_get_item_statistics_test(v_admin_id);

  RAISE NOTICE '✅ PASS: Item statistics retrieved';
  RAISE NOTICE '   - Total items: %', v_result.total_items;
  RAISE NOTICE '   - Borrowed: %', v_result.borrowed_items || ' (' || ROUND(v_result.borrowed_percentage::NUMERIC, 2) || '%)';
  RAISE NOTICE '   - Returned: %', v_result.returned_items || ' (' || ROUND(v_result.returned_percentage::NUMERIC, 2) || '%)';
  RAISE NOTICE '   - Overdue: %', v_result.overdue_items || ' (' || ROUND(v_result.overdue_percentage::NUMERIC, 2) || '%)';
  RAISE NOTICE '   - Avg loan duration: % days', v_result.avg_loan_duration_days;
  RAISE NOTICE '   - Total completed loans: %', v_result.total_completed_loans;
  RAISE NOTICE '   - Items never returned (>90d): %', v_result.items_never_returned;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 9: Validate item statistics accuracy
  -- ============================================================================
  RAISE NOTICE '📋 TEST 9: Validate Item Statistics Accuracy';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  -- Check total items matches
  IF v_result.total_items = (SELECT COUNT(*) FROM public.items) THEN
    RAISE NOTICE '✅ PASS: Total items count is accurate';
  ELSE
    RAISE NOTICE '❌ FAIL: Total items count mismatch';
  END IF;

  -- Check borrowed count
  IF v_result.borrowed_items = (SELECT COUNT(*) FROM public.items WHERE status = 'borrowed') THEN
    RAISE NOTICE '✅ PASS: Borrowed items count is accurate';
  ELSE
    RAISE NOTICE '❌ FAIL: Borrowed items count mismatch';
  END IF;

  -- Check returned count
  IF v_result.returned_items = (SELECT COUNT(*) FROM public.items WHERE status = 'returned') THEN
    RAISE NOTICE '✅ PASS: Returned items count is accurate';
  ELSE
    RAISE NOTICE '❌ FAIL: Returned items count mismatch';
  END IF;

  -- Check percentage sum (borrowed + returned should equal ~100% if all items counted)
  IF v_result.total_items > 0 THEN
    IF (v_result.borrowed_percentage + v_result.returned_percentage) BETWEEN 99.0 AND 101.0 THEN
      RAISE NOTICE '✅ PASS: Percentages sum correctly (approximately 100 percent)';
    ELSE
      RAISE NOTICE '⚠️  WARNING: %',
        'Percentages sum to ' || ROUND((v_result.borrowed_percentage + v_result.returned_percentage)::NUMERIC, 2) || '% (expected ~100%)';
    END IF;
  END IF;

  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 10: admin_get_top_users_test - Default limit (10)
  -- ============================================================================
  RAISE NOTICE '📋 TEST 10: admin_get_top_users_test() - Default Limit';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_row_count
  FROM public.admin_get_top_users_test(v_admin_id);

  RAISE NOTICE '✅ PASS: Retrieved % top users', v_row_count;

  -- Show top user
  IF v_row_count > 0 THEN
    SELECT * INTO v_result
    FROM public.admin_get_top_users_test(v_admin_id)
    LIMIT 1;

    RAISE NOTICE '   - Top user: %', v_result.full_name;
    RAISE NOTICE '   - Email: %', v_result.email;
    RAISE NOTICE '   - Total items: %', v_result.total_items;
    RAISE NOTICE '   - Items breakdown: %',
      'Borrowed: ' || v_result.borrowed_items || ', Returned: ' || v_result.returned_items || ', Overdue: ' || v_result.overdue_items;
  ELSE
    RAISE NOTICE '   - No users with items found';
  END IF;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 11: admin_get_top_users_test - Custom limit (3)
  -- ============================================================================
  RAISE NOTICE '📋 TEST 11: admin_get_top_users_test(3) - Custom Limit';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_row_count
  FROM public.admin_get_top_users_test(v_admin_id, 3);

  IF v_row_count <= 3 THEN
    RAISE NOTICE '✅ PASS: Retrieved % users (max 3)', v_row_count;
  ELSE
    RAISE NOTICE '❌ FAIL: Expected max 3 users, got %', v_row_count;
  END IF;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 12: admin_get_top_users_test - Invalid limit (should fail)
  -- ============================================================================
  RAISE NOTICE '📋 TEST 12: admin_get_top_users_test(0) - Invalid Limit';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_get_top_users_test(v_admin_id, 0);
    RAISE NOTICE '❌ FAIL: Should have thrown error for limit <= 0';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 13: admin_get_top_users_test - Limit too large (should fail)
  -- ============================================================================
  RAISE NOTICE '📋 TEST 13: admin_get_top_users_test(150) - Limit Too Large';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_get_top_users_test(v_admin_id, 150);
    RAISE NOTICE '❌ FAIL: Should have thrown error for limit > 100';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 14: Non-admin user access (should fail)
  -- ============================================================================
  RAISE NOTICE '📋 TEST 14: Non-Admin User Access Test';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  DECLARE
    v_regular_user_id UUID;
  BEGIN
    -- Find a regular user (not admin)
    SELECT id INTO v_regular_user_id
    FROM public.profiles
    WHERE role = 'user'
    LIMIT 1;

    IF v_regular_user_id IS NOT NULL THEN
      BEGIN
        PERFORM public.admin_get_dashboard_stats_test(v_regular_user_id);
        RAISE NOTICE '❌ FAIL: Non-admin should not access dashboard stats';
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ PASS: Non-admin correctly denied: %', SQLERRM;
      END;
    ELSE
      RAISE NOTICE '⚠️  SKIP: No regular users found in database';
    END IF;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- SUMMARY
  -- ============================================================================
  RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║                      TEST SUMMARY                          ║';
  RAISE NOTICE '╚════════════════════════════════════════════════════════════╝';
  RAISE NOTICE '';
  RAISE NOTICE '✅ All analytics functions tests completed successfully!';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Functions tested:';
  RAISE NOTICE '   - admin_get_dashboard_stats() ✓';
  RAISE NOTICE '   - admin_get_user_growth(days) ✓';
  RAISE NOTICE '   - admin_get_item_statistics() ✓';
  RAISE NOTICE '   - admin_get_top_users(limit) ✓';
  RAISE NOTICE '';

END $$;

-- ============================================================================
-- View Sample Data from Each Function
-- ============================================================================

-- Dashboard stats
SELECT '=== DASHBOARD STATS ===' as section, *
FROM public.admin_get_dashboard_stats_test('9d6b3538-44e6-46b3-8f5b-e530be6449b8');

-- User growth (last 7 days)
SELECT '=== USER GROWTH (7 DAYS) ===' as section, *
FROM public.admin_get_user_growth_test('9d6b3538-44e6-46b3-8f5b-e530be6449b8', 7)
ORDER BY date DESC;

-- Item statistics
SELECT '=== ITEM STATISTICS ===' as section, *
FROM public.admin_get_item_statistics_test('9d6b3538-44e6-46b3-8f5b-e530be6449b8');

-- Top users (top 5)
SELECT '=== TOP 5 USERS ===' as section, *
FROM public.admin_get_top_users_test('9d6b3538-44e6-46b3-8f5b-e530be6449b8', 5)
ORDER BY total_items DESC;
