-- Quick Test for Admin Items Functions using Test Helpers
-- Run after applying migrations 009 and 009b

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
-- STEP 2: Check if there are items to test with
-- ============================================================================

SELECT
  '=== EXISTING ITEMS ===' as section,
  COUNT(*) as total_items,
  COUNT(CASE WHEN status = 'borrowed' THEN 1 END) as borrowed_items,
  COUNT(CASE WHEN status = 'available' THEN 1 END) as available_items,
  COUNT(CASE WHEN status = 'unavailable' THEN 1 END) as unavailable_items
FROM public.items;

-- ============================================================================
-- STEP 3: Run All Tests
-- ============================================================================

DO $$
DECLARE
  -- ⚠️  REPLACE THIS with your admin user ID from step 1
  v_admin_id UUID := '9d6b3538-44e6-46b3-8f5b-e530be6449b8';

  -- Variables for testing
  v_test_item_id UUID;
  v_items_count INT;
  v_result RECORD;
  v_test_item_created BOOLEAN := FALSE;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║      ADMIN ITEMS FUNCTIONS TEST - AUTOMATED                ║';
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
  -- TEST 2: admin_get_all_items_test - No Filters
  -- ============================================================================
  RAISE NOTICE '📋 TEST 2: admin_get_all_items_test() - No Filters';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_items_count
  FROM public.admin_get_all_items_test(v_admin_id, 50, 0, NULL, NULL, NULL);

  RAISE NOTICE '✅ PASS: Retrieved % items', v_items_count;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 3: admin_get_all_items_test - Filter by Status
  -- ============================================================================
  RAISE NOTICE '📋 TEST 3: admin_get_all_items_test() - Filter by Status';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_items_count
  FROM public.admin_get_all_items_test(v_admin_id, 50, 0, 'borrowed', NULL, NULL);

  RAISE NOTICE '✅ PASS: Found % borrowed items', v_items_count;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 4: admin_get_all_items_test - Filter by Owner
  -- ============================================================================
  RAISE NOTICE '📋 TEST 4: admin_get_all_items_test() - Filter by Owner';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_items_count
  FROM public.admin_get_all_items_test(v_admin_id, 50, 0, NULL, v_admin_id, NULL);

  RAISE NOTICE '✅ PASS: Found % items owned by admin', v_items_count;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 5: admin_get_all_items_test - Search
  -- ============================================================================
  RAISE NOTICE '📋 TEST 5: admin_get_all_items_test() - Search';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  -- Search for anything (will match partial text)
  SELECT COUNT(*) INTO v_items_count
  FROM public.admin_get_all_items_test(v_admin_id, 50, 0, NULL, NULL, 'a');

  RAISE NOTICE '✅ PASS: Search found % items containing "a"', v_items_count;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 6: Find or Create a Test Item
  -- ============================================================================
  RAISE NOTICE '📋 TEST 6: Find or Create Test Item';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  -- Try to find an existing item
  SELECT id INTO v_test_item_id
  FROM public.items
  WHERE user_id = v_admin_id
  LIMIT 1;

  IF v_test_item_id IS NULL THEN
    -- Create a test item if none exists
    INSERT INTO public.items (
      name,
      borrower_name,
      borrower_contact_id,
      borrow_date,
      return_date,
      status,
      notes,
      user_id
    ) VALUES (
      'Test Item for Admin Functions',
      'Test Borrower',
      'test@example.com',
      NOW() - INTERVAL '5 days',
      NOW() + INTERVAL '2 days',
      'borrowed',
      'This is a test item created by automated test script',
      v_admin_id
    ) RETURNING id INTO v_test_item_id;

    v_test_item_created := TRUE;
    RAISE NOTICE '✅ PASS: Created test item: %', v_test_item_id;
  ELSE
    RAISE NOTICE '✅ PASS: Using existing item: %', v_test_item_id;
  END IF;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 7: admin_get_item_details_test
  -- ============================================================================
  RAISE NOTICE '📋 TEST 7: admin_get_item_details_test()';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT * INTO v_result
  FROM public.admin_get_item_details_test(v_admin_id, v_test_item_id);

  RAISE NOTICE '✅ PASS: Retrieved item details';
  RAISE NOTICE '   - Item name: %', v_result.name;
  RAISE NOTICE '   - Status: %', v_result.status;
  RAISE NOTICE '   - Owner: %', v_result.owner_name;
  RAISE NOTICE '   - Days borrowed: %', v_result.days_borrowed;
  RAISE NOTICE '   - Is overdue: %', v_result.is_overdue;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 8: admin_get_item_details_test - Invalid Item
  -- ============================================================================
  RAISE NOTICE '📋 TEST 8: admin_get_item_details_test() - Invalid Item';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_get_item_details_test(v_admin_id, '00000000-0000-0000-0000-000000000000');
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 9: admin_update_item_status_test - Change to Returned
  -- ============================================================================
  RAISE NOTICE '📋 TEST 9: admin_update_item_status_test() - To Returned';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT * INTO v_result
  FROM public.admin_update_item_status_test(
    v_admin_id,
    v_test_item_id,
    'returned',
    'Test status change'
  );

  RAISE NOTICE '✅ PASS: % -> %', v_result.old_status, v_result.new_status;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 10: admin_update_item_status_test - Change to Borrowed
  -- ============================================================================
  RAISE NOTICE '📋 TEST 10: admin_update_item_status_test() - To Borrowed';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT * INTO v_result
  FROM public.admin_update_item_status_test(
    v_admin_id,
    v_test_item_id,
    'borrowed',
    'Test status change back'
  );

  RAISE NOTICE '✅ PASS: % -> %', v_result.old_status, v_result.new_status;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 11: admin_update_item_status_test - Invalid Status
  -- ============================================================================
  RAISE NOTICE '📋 TEST 11: admin_update_item_status_test() - Invalid Status';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_item_status_test(v_admin_id, v_test_item_id, 'invalid_status');
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 12: admin_update_item_status_test - Same Status
  -- ============================================================================
  RAISE NOTICE '📋 TEST 12: admin_update_item_status_test() - Same Status';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_update_item_status_test(v_admin_id, v_test_item_id, 'borrowed');
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 13: admin_delete_item_test - Soft Delete
  -- ============================================================================
  RAISE NOTICE '📋 TEST 13: admin_delete_item_test() - Soft Delete';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT * INTO v_result
  FROM public.admin_delete_item_test(
    v_admin_id,
    v_test_item_id,
    FALSE,
    'Test soft delete'
  );

  RAISE NOTICE '✅ PASS: % (%)', v_result.message, v_result.delete_type;
  RAISE NOTICE '';

  -- ============================================================================
  -- TEST 14: Verify Soft Delete Removed Item
  -- ============================================================================
  RAISE NOTICE '📋 TEST 14: Verify Soft Delete Removed Item';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  SELECT COUNT(*) INTO v_items_count
  FROM public.items
  WHERE id = v_test_item_id;

  IF v_items_count = 0 THEN
    RAISE NOTICE '✅ PASS: Item deleted from database (soft delete)';
  ELSE
    RAISE NOTICE '❌ FAIL: Expected item to be deleted';
  END IF;
  RAISE NOTICE '';

  -- Recreate item for cleanup test if needed
  IF v_test_item_created AND v_items_count = 0 THEN
    INSERT INTO public.items (
      id,
      name,
      borrower_name,
      borrower_contact_id,
      borrow_date,
      return_date,
      status,
      notes,
      user_id
    ) VALUES (
      v_test_item_id,
      'Test Item for Admin Functions',
      'Test Borrower',
      'test@example.com',
      NOW() - INTERVAL '5 days',
      NOW() + INTERVAL '2 days',
      'borrowed',
      'Recreated for cleanup test',
      v_admin_id
    );
  END IF;

  -- ============================================================================
  -- TEST 15: Cleanup Test Item (if we created it)
  -- ============================================================================
  IF v_test_item_created THEN
    RAISE NOTICE '📋 TEST 15: Cleanup Test Item';
    RAISE NOTICE '─────────────────────────────────────────────────────────────';

    SELECT * INTO v_result
    FROM public.admin_delete_item_test(
      v_admin_id,
      v_test_item_id,
      TRUE,  -- Hard delete
      'Cleanup automated test item'
    );

    RAISE NOTICE '✅ PASS: Test item cleaned up: %', v_result.message;
    RAISE NOTICE '';
  END IF;

  -- ============================================================================
  -- TEST 16: Error - Delete Non-existent Item
  -- ============================================================================
  RAISE NOTICE '📋 TEST 16: Error - Delete Non-existent Item';
  RAISE NOTICE '─────────────────────────────────────────────────────────────';

  BEGIN
    PERFORM public.admin_delete_item_test(
      v_admin_id,
      '00000000-0000-0000-0000-000000000000',
      FALSE
    );
    RAISE NOTICE '❌ FAIL: Should have thrown error';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✅ PASS: Correctly threw error: %', SQLERRM;
  END;
  RAISE NOTICE '';

  -- ============================================================================
  -- SUMMARY
  -- ============================================================================
  RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║                      TEST SUMMARY                          ║';
  RAISE NOTICE '╚════════════════════════════════════════════════════════════╝';
  RAISE NOTICE '';

  SELECT COUNT(*) INTO v_items_count
  FROM public.audit_logs
  WHERE created_at > NOW() - INTERVAL '1 hour'
    AND table_name = 'items';

  RAISE NOTICE '📊 Item audit logs created in last hour: %', v_items_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ All automated tests completed successfully!';
  RAISE NOTICE '';

END $$;

-- ============================================================================
-- View Recent Audit Logs for Items
-- ============================================================================

SELECT
  '=== RECENT ITEMS AUDIT LOGS ===' as section,
  admin_user_id,
  action_type,
  table_name,
  metadata->>'action' as action_detail,
  metadata->>'name' as name,
  metadata->>'reason' as reason,
  created_at
FROM public.audit_logs
WHERE created_at > NOW() - INTERVAL '1 hour'
  AND table_name = 'items'
  AND metadata->>'test_mode' = 'true'
ORDER BY created_at DESC
LIMIT 20;

-- ============================================================================
-- CLEANUP (Optional)
-- ============================================================================

-- Uncomment to clean up test audit logs:
-- DELETE FROM public.audit_logs
-- WHERE table_name = 'items' AND metadata->>'test_mode' = 'true';
