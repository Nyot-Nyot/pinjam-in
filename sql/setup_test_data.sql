-- Setup Test Data for RLS Testing
-- Purpose: Get actual user IDs and prepare test data
-- Run this BEFORE running test_rls_policies.sql

-- ============================================================================
-- STEP 1: Check your current user
-- ============================================================================
SELECT
  auth.uid() as current_user_id,
  p.full_name,
  p.role,
  p.status
FROM public.profiles p
WHERE p.id = auth.uid();

-- ============================================================================
-- STEP 2: List all users in the system
-- ============================================================================
SELECT
  p.id,
  p.full_name,
  p.role,
  p.status,
  au.email,
  au.created_at
FROM public.profiles p
LEFT JOIN auth.users au ON au.id = p.id
ORDER BY p.role DESC, au.created_at;

-- ============================================================================
-- STEP 3: Check if you have test users
-- ============================================================================
SELECT
  (SELECT COUNT(*) FROM public.profiles WHERE role = 'admin') as admin_count,
  (SELECT COUNT(*) FROM public.profiles WHERE role = 'user') as regular_user_count,
  (SELECT COUNT(*) FROM public.profiles) as total_users;

-- ============================================================================
-- STEP 4: Promote current user to admin (if needed)
-- ============================================================================
-- Uncomment and run if you need to make yourself admin:
-- UPDATE public.profiles SET role = 'admin' WHERE id = auth.uid();
-- Then LOGOUT and LOGIN again to refresh JWT token

-- ============================================================================
-- STEP 5: Copy User IDs for test script
-- ============================================================================
-- After running steps above, you should see user IDs like:
--
-- Regular User ID: abc123-def456-ghi789-...
-- Admin User ID:   xyz789-uvw456-rst123-...
--
-- NEXT STEPS:
-- 1. Copy one regular user UUID
-- 2. Copy one admin user UUID
-- 3. Replace in test_rls_policies.sql:
--    - All '<user_a_id>' with regular user UUID
--    - All '<user_b_id>' with admin user UUID
--    - Or use the auto-replace script below

-- ============================================================================
-- OPTION: Use test with auth.uid() directly
-- ============================================================================
-- You can also modify test_rls_policies.sql to use auth.uid() instead of hardcoded UUIDs
-- This way you can run tests as different users by logging in as them
