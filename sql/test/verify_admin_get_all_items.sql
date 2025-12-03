-- Quick test to verify admin_get_all_items function exists and works
-- Run this in Supabase SQL Editor as authenticated admin user

-- Test 1: Check if function exists
SELECT
  routine_name,
  routine_type,
  data_type,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'admin_get_all_items';

-- Expected result: One row with routine_name = 'admin_get_all_items', routine_type = 'FUNCTION'
-- If no rows returned, migration 009 hasn't been applied yet!

-- Test 2: Check current user and role
SELECT
  auth.uid() as current_user_id,
  auth.email() as current_email,
  (SELECT role FROM profiles WHERE id = auth.uid()) as user_role,
  public.is_admin(auth.uid()) as is_admin_result;

-- Expected result: Shows your current user info and is_admin_result should be TRUE

-- Test 3: Try to call the function with minimal parameters
SELECT
  id,
  name,
  status,
  owner_name,
  owner_email,
  is_overdue
FROM admin_get_all_items(p_limit := 5, p_offset := 0)
LIMIT 5;

-- Expected result: List of items (or empty if no items exist)
-- If error "function admin_get_all_items does not exist" → Run migration 009
-- If error "Permission denied" → Your user is not admin or is_admin() function has issues
