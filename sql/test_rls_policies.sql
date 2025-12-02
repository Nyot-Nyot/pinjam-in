-- RLS Security Testing Script
-- Purpose: Verify that Row Level Security policies work correctly for different user roles
-- Date: 2025-12-02
--
-- INSTRUCTIONS:
-- 1. Run this script in Supabase SQL Editor
-- 2. You need TWO test users in auth.users:
--    - User A (regular user): role='user' in profiles
--    - User B (admin user): role='admin' in profiles
-- 3. Replace <user_a_id> and <user_b_id> with actual UUIDs below
-- 4. Check each test result to verify expected behavior

-- ============================================================================
-- SETUP: Create Test Data
-- ============================================================================

-- Replace these with actual user IDs from your auth.users table
-- Get them by running: SELECT id, email FROM auth.users LIMIT 5;
DO $$
DECLARE
    user_a_id UUID := '<user_a_id>'; -- Regular user
    user_b_id UUID := '<user_b_id>'; -- Admin user
BEGIN
    -- Insert test profiles if they don't exist
    INSERT INTO public.profiles (id, full_name, role, status)
    VALUES
        (user_a_id, 'Test User A', 'user', 'active'),
        (user_b_id, 'Test Admin B', 'admin', 'active')
    ON CONFLICT (id) DO UPDATE
    SET role = EXCLUDED.role, status = EXCLUDED.status;

    -- Insert test items
    INSERT INTO public.items (id, user_id, name, borrower_name, status)
    VALUES
        (gen_random_uuid(), user_a_id, 'User A Item 1', 'Borrower 1', 'borrowed'),
        (gen_random_uuid(), user_a_id, 'User A Item 2', 'Borrower 2', 'returned'),
        (gen_random_uuid(), user_b_id, 'Admin B Item 1', 'Borrower 3', 'borrowed')
    ON CONFLICT DO NOTHING;

    -- Insert test audit log (only admin can do this)
    INSERT INTO public.audit_logs (admin_user_id, action_type, table_name, record_id, metadata)
    VALUES (user_b_id, 'create', 'items', gen_random_uuid(), '{"test": true}')
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Test data setup complete';
END $$;

-- ============================================================================
-- TEST 1: PROFILES TABLE - SELECT POLICY
-- ============================================================================
-- Expected: Regular user sees only their own profile
--           Admin sees all profiles

-- Test as User A (regular user)
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 1.1: User A SELECT profiles' AS test_name;
SELECT id, full_name, role FROM public.profiles;
-- Expected: 1 row (only User A's profile)

ROLLBACK;

-- Test as User B (admin)
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 1.2: Admin B SELECT profiles' AS test_name;
SELECT id, full_name, role FROM public.profiles;
-- Expected: 2+ rows (all profiles including User A and User B)

ROLLBACK;

-- ============================================================================
-- TEST 2: PROFILES TABLE - UPDATE POLICY
-- ============================================================================
-- Expected: Users can update own profile
--           Admin can update all profiles

-- Test as User A updating own profile
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 2.1: User A UPDATE own profile' AS test_name;
UPDATE public.profiles SET full_name = 'User A Updated' WHERE id = '<user_a_id>';
-- Expected: 1 row updated

-- Try to update Admin B's profile (should fail)
SELECT 'TEST 2.2: User A UPDATE Admin B profile (should fail)' AS test_name;
UPDATE public.profiles SET full_name = 'Hacked' WHERE id = '<user_b_id>';
-- Expected: 0 rows updated

ROLLBACK;

-- Test as Admin updating any profile
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 2.3: Admin B UPDATE any profile' AS test_name;
UPDATE public.profiles SET full_name = 'Admin Updated User A' WHERE id = '<user_a_id>';
-- Expected: 1 row updated

ROLLBACK;

-- ============================================================================
-- TEST 3: PROFILES TABLE - INSERT POLICY
-- ============================================================================
-- Expected: Users can insert own profile
--           Admin can insert any profile

-- Test as User (create new profile with matching ID)
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 3.1: User A INSERT own profile' AS test_name;
-- In real scenario, this would happen during signup
-- Skipping because user_a_id already exists

ROLLBACK;

-- Test as Admin creating profile for another user
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 3.2: Admin B INSERT profile for new user' AS test_name;
-- Skipping actual insert to avoid creating dummy users
-- Expected: Would succeed if user_id is valid

ROLLBACK;

-- ============================================================================
-- TEST 4: PROFILES TABLE - DELETE POLICY
-- ============================================================================
-- Expected: Only admin can delete profiles
--           Regular users cannot delete even their own profile

-- Test as User A trying to delete own profile (should fail)
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 4.1: User A DELETE own profile (should fail)' AS test_name;
DELETE FROM public.profiles WHERE id = '<user_a_id>';
-- Expected: 0 rows deleted

ROLLBACK;

-- Test as Admin deleting a profile
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 4.2: Admin B DELETE any profile (would succeed)' AS test_name;
-- Skipping actual delete to preserve test data
-- Expected: Would delete if executed

ROLLBACK;

-- ============================================================================
-- TEST 5: ITEMS TABLE - SELECT POLICY
-- ============================================================================
-- Expected: Users see only own items
--           Admin sees all items

-- Test as User A
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 5.1: User A SELECT items' AS test_name;
SELECT id, name, user_id FROM public.items;
-- Expected: 2 rows (only User A's items)

ROLLBACK;

-- Test as Admin B
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 5.2: Admin B SELECT items' AS test_name;
SELECT id, name, user_id FROM public.items;
-- Expected: 3+ rows (all items from all users)

ROLLBACK;

-- ============================================================================
-- TEST 6: ITEMS TABLE - INSERT POLICY
-- ============================================================================
-- Expected: Users can insert own items
--           Admin can insert items for any user

-- Test as User A inserting own item
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 6.1: User A INSERT own item' AS test_name;
INSERT INTO public.items (user_id, name, borrower_name)
VALUES ('<user_a_id>', 'Test Item', 'Test Borrower');
-- Expected: 1 row inserted

ROLLBACK;

-- Test as Admin inserting item for another user
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 6.2: Admin B INSERT item for User A' AS test_name;
INSERT INTO public.items (user_id, name, borrower_name)
VALUES ('<user_a_id>', 'Admin Created Item', 'Test Borrower');
-- Expected: 1 row inserted

ROLLBACK;

-- ============================================================================
-- TEST 7: ITEMS TABLE - UPDATE POLICY
-- ============================================================================
-- Expected: Users can update own items
--           Admin can update all items

-- Test as User A updating own item
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 7.1: User A UPDATE own item' AS test_name;
UPDATE public.items SET name = 'Updated by User A'
WHERE user_id = '<user_a_id>' AND id = (
  SELECT id FROM public.items WHERE user_id = '<user_a_id>' LIMIT 1
);
-- Expected: 1 row updated

-- Try to update Admin's item (should fail)
SELECT 'TEST 7.2: User A UPDATE Admin item (should fail)' AS test_name;
UPDATE public.items SET name = 'Hacked'
WHERE user_id = '<user_b_id>';
-- Expected: 0 rows updated

ROLLBACK;

-- Test as Admin updating any item
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 7.3: Admin B UPDATE any item' AS test_name;
UPDATE public.items SET name = 'Updated by Admin'
WHERE user_id = '<user_a_id>' AND id = (
  SELECT id FROM public.items WHERE user_id = '<user_a_id>' LIMIT 1
);
-- Expected: 1 row updated

ROLLBACK;

-- ============================================================================
-- TEST 8: ITEMS TABLE - DELETE POLICY
-- ============================================================================
-- Expected: Users can delete own items
--           Admin can delete all items

-- Test as User A deleting own item
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 8.1: User A DELETE own item' AS test_name;
-- Skipping actual delete to preserve test data
-- Expected: Would delete if executed

ROLLBACK;

-- Test as Admin deleting any item
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 8.2: Admin B DELETE any item' AS test_name;
-- Skipping actual delete to preserve test data
-- Expected: Would delete if executed

ROLLBACK;

-- ============================================================================
-- TEST 9: AUDIT_LOGS TABLE - SELECT POLICY
-- ============================================================================
-- Expected: Only admin can view audit logs
--           Regular users cannot view

-- Test as User A (should see nothing)
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 9.1: User A SELECT audit_logs (should be empty)' AS test_name;
SELECT COUNT(*) FROM public.audit_logs;
-- Expected: 0 rows

ROLLBACK;

-- Test as Admin (should see all logs)
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 9.2: Admin B SELECT audit_logs' AS test_name;
SELECT COUNT(*) FROM public.audit_logs;
-- Expected: 1+ rows

ROLLBACK;

-- ============================================================================
-- TEST 10: AUDIT_LOGS TABLE - INSERT POLICY
-- ============================================================================
-- Expected: Only admin can insert audit logs
--           Regular users cannot insert

-- Test as User A (should fail)
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_a_id>';

SELECT 'TEST 10.1: User A INSERT audit_log (should fail)' AS test_name;
INSERT INTO public.audit_logs (admin_user_id, action_type, table_name, record_id)
VALUES ('<user_a_id>', 'create', 'test', gen_random_uuid());
-- Expected: Error or 0 rows inserted

ROLLBACK;

-- Test as Admin (should succeed)
BEGIN;
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims.sub TO '<user_b_id>';

SELECT 'TEST 10.2: Admin B INSERT audit_log' AS test_name;
INSERT INTO public.audit_logs (admin_user_id, action_type, table_name, record_id)
VALUES ('<user_b_id>', 'update', 'items', gen_random_uuid());
-- Expected: 1 row inserted

ROLLBACK;

-- ============================================================================
-- TEST 11: STORAGE POLICIES (CONCEPTUAL)
-- ============================================================================
-- Note: Storage policies cannot be tested via SQL directly
-- They must be tested via Supabase client SDK or REST API
--
-- Expected behavior:
-- 1. Users can SELECT/INSERT/UPDATE/DELETE files in folder: {user_id}/*
-- 2. Admin can SELECT/INSERT/UPDATE/DELETE all files in bucket: item_photos/*
--
-- Manual test steps:
-- 1. As User A: Upload file to item_photos/{user_a_id}/test.jpg (should succeed)
-- 2. As User A: Try to view item_photos/{user_b_id}/test.jpg (should fail)
-- 3. As Admin B: View item_photos/{user_a_id}/test.jpg (should succeed)
-- 4. As Admin B: Delete item_photos/{user_a_id}/test.jpg (should succeed)

SELECT '============================================' AS separator;
SELECT 'RLS SECURITY TESTS COMPLETE' AS status;
SELECT 'Review results above to verify expected behavior' AS instruction;
SELECT '============================================' AS separator;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to check test data and policy status

-- Check all profiles
SELECT 'All Profiles:' AS info;
SELECT id, full_name, role, status FROM public.profiles;

-- Check all items
SELECT 'All Items:' AS info;
SELECT id, name, user_id FROM public.items;

-- Check all audit logs
SELECT 'All Audit Logs:' AS info;
SELECT id, admin_user_id, action_type, table_name FROM public.audit_logs;

-- Check RLS status
SELECT 'RLS Status:' AS info;
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'items', 'audit_logs');

-- Check policies count
SELECT 'Policy Count:' AS info;
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename;
