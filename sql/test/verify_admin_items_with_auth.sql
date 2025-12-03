-- Test admin_get_all_items function with explicit authentication
-- Run this in Supabase SQL Editor

-- First, find your admin user ID
SELECT
  id,
  email,
  raw_user_meta_data,
  created_at
FROM auth.users
WHERE email = 'admin@gmail.com';
-- Copy the 'id' value from the result

-- Then check profile
SELECT
  id,
  email,
  full_name,
  role,
  status
FROM profiles
WHERE email = 'admin@gmail.com';
-- Verify role = 'admin'

-- Now test is_admin function directly with your user ID
-- Replace 'YOUR_USER_ID_HERE' with actual UUID from above
SELECT public.is_admin('YOUR_USER_ID_HERE'::uuid) as is_admin_check;
-- Should return TRUE

-- Finally, call the function using SECURITY DEFINER bypass
-- This simulates what happens when called from your Flutter app
SELECT
  id,
  name,
  status,
  owner_name,
  owner_email,
  is_overdue
FROM admin_get_all_items(
  p_limit := 10,
  p_offset := 0,
  p_status_filter := NULL,
  p_user_filter := NULL,
  p_search := NULL
)
LIMIT 10;
