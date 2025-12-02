-- Simple RLS Test Script
-- Purpose: Test RLS policies using current authenticated user (auth.uid())
-- No need to replace UUIDs - just login as different users and run each test

-- ============================================================================
-- PRE-REQUISITES
-- ============================================================================
-- 1. You must be logged in to Supabase SQL Editor
-- 2. You need at least 2 users: 1 regular user, 1 admin user
-- 3. Run setup_test_data.sql first to check your users
-- 4. IMPORTANT: Make sure you're using SQL Editor in Supabase Dashboard
--    The SQL Editor automatically sets auth.uid() to your logged-in user

-- ============================================================================
-- SAFETY CHECK: Are you authenticated?
-- ============================================================================
DO $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'ERROR: auth.uid() is NULL. You must be logged in to run this test. Please use Supabase Dashboard SQL Editor and make sure you are logged in.';
  END IF;
END $$;

-- ============================================================================
-- TEST SETUP: Check who you are
-- ============================================================================
SELECT
  '=== CURRENT USER INFO ===' as test_section,
  auth.uid() as my_user_id,
  p.full_name as my_name,
  p.role as my_role,
  p.status as my_status,
  public.is_admin(auth.uid()) as am_i_admin
FROM public.profiles p
WHERE p.id = auth.uid();

-- ============================================================================
-- TEST 1: Can I query is_admin() without recursion?
-- ============================================================================
SELECT
  '=== TEST 1: is_admin() Function ===' as test_section,
  public.is_admin(auth.uid()) as is_admin_result,
  CASE
    WHEN public.is_admin(auth.uid()) THEN '✅ PASS: I am admin'
    ELSE '✅ PASS: I am regular user'
  END as test_result;

-- Expected: No recursion error, returns true/false

-- ============================================================================
-- TEST 2: Can I view my own profile?
-- ============================================================================
SELECT
  '=== TEST 2: View Own Profile ===' as test_section,
  id,
  full_name,
  role,
  status
FROM public.profiles
WHERE id = auth.uid();

-- Expected: Returns your profile data

-- ============================================================================
-- TEST 3: Can I view OTHER users' profiles?
-- ============================================================================
SELECT
  '=== TEST 3: View Other Profiles ===' as test_section,
  COUNT(*) as other_profiles_visible
FROM public.profiles
WHERE id != auth.uid();

-- Expected:
-- - Regular user: 0 (cannot see other profiles)
-- - Admin user: Should return 0 because profiles RLS only allows own profile
--   (Admin must use service role to view all profiles)

-- ============================================================================
-- TEST 4: Can I update my own profile?
-- ============================================================================
-- Test UPDATE
UPDATE public.profiles
SET full_name = full_name || ' (tested)'
WHERE id = auth.uid();

-- Verify
SELECT
  '=== TEST 4: Update Own Profile ===' as test_section,
  id,
  full_name,
  role
FROM public.profiles
WHERE id = auth.uid();

-- Expected: full_name should have " (tested)" appended

-- Cleanup: Reset full_name
UPDATE public.profiles
SET full_name = REPLACE(full_name, ' (tested)', '')
WHERE id = auth.uid();

-- ============================================================================
-- TEST 5: Can I view my own items?
-- ============================================================================
SELECT
  '=== TEST 5: View Own Items ===' as test_section,
  COUNT(*) as my_items_count
FROM public.items
WHERE user_id = auth.uid();

-- Expected: Returns count of your items (could be 0 if no items yet)

-- ============================================================================
-- TEST 6: Can I view ALL items? (Admin test)
-- ============================================================================
SELECT
  '=== TEST 6: View All Items ===' as test_section,
  COUNT(*) as all_items_count,
  COUNT(DISTINCT user_id) as unique_owners,
  CASE
    WHEN public.is_admin(auth.uid()) THEN
      '✅ PASS: Admin can see all items'
    WHEN COUNT(*) = (SELECT COUNT(*) FROM public.items WHERE user_id = auth.uid()) THEN
      '✅ PASS: Regular user can only see own items'
    ELSE
      '❌ FAIL: Regular user seeing items they should not'
  END as test_result
FROM public.items;

-- Expected:
-- - Regular user: Only see own items
-- - Admin: Can see all items

-- ============================================================================
-- TEST 7: Can I create an item?
-- ============================================================================
-- Insert test item
INSERT INTO public.items (user_id, name, borrower_name, borrow_date, status)
VALUES (
  auth.uid(),
  'Test Item ' || NOW()::TEXT,
  'Test Borrower',
  NOW(),
  'borrowed'
)
RETURNING id, name, status;

-- Expected:
-- - Regular user: Success if user_id = auth.uid()
-- - Admin: Success

-- Cleanup: Delete test item (only admins can delete)
-- If you're admin, uncomment below:
-- DELETE FROM public.items WHERE name LIKE 'Test Item %';

-- ============================================================================
-- TEST 8: Can I view audit logs?
-- ============================================================================
SELECT
  '=== TEST 8: View Audit Logs ===' as test_section,
  COUNT(*) as audit_logs_count,
  CASE
    WHEN public.is_admin(auth.uid()) THEN
      '✅ PASS: Admin can see audit logs'
    ELSE
      '❌ Should fail: Regular user cannot see audit logs'
  END as test_result
FROM public.audit_logs;

-- Expected:
-- - Regular user: 0 rows (RLS blocks access)
-- - Admin: All audit logs visible

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
SELECT
  '=== TEST SUMMARY ===' as section,
  public.is_admin(auth.uid()) as tested_as_admin,
  (SELECT COUNT(*) FROM public.profiles WHERE id = auth.uid()) as can_view_own_profile,
  (SELECT COUNT(*) FROM public.items WHERE user_id = auth.uid()) as can_view_own_items,
  (SELECT COUNT(*) FROM public.audit_logs) as can_view_audit_logs;

-- ============================================================================
-- NEXT STEPS
-- ============================================================================
-- 1. Run this script as REGULAR USER first
--    - All tests should pass
--    - You should only see your own data
--    - Audit logs should be 0 or error
--
-- 2. Then run this script as ADMIN USER
--    - All tests should pass
--    - You should see all items
--    - You should see all audit logs
--
-- 3. If any test fails, check the error message and report it
