-- Quick Test: Call admin_get_user_details directly
-- Run this in Supabase SQL Editor

-- First, get a user ID to test with
SELECT id, full_name, email
FROM public.profiles
LIMIT 5;

-- Then, copy one of the user IDs and replace 'PASTE_USER_ID_HERE' below
-- Example: SELECT * FROM admin_get_user_details('123e4567-e89b-12d3-a456-426614174000');

SELECT * FROM admin_get_user_details('PASTE_USER_ID_HERE');

-- If you get error "column p.created_at does not exist",
-- it means the function wasn't properly updated.
--
-- If you get "Permission denied", you need to be logged in as admin
--
-- If you get data back, the function works! The issue is in the Flutter app.
