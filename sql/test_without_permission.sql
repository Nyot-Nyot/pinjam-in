-- Test admin_get_user_details WITHOUT permission check
-- This bypasses the is_admin() check to test if the function works

-- Option A: Temporarily disable permission check
-- Run this to see if function structure is correct:

-- 1. First, let's check the actual function code
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'admin_get_user_details';

-- Look for this line in output:
-- LEFT JOIN public.items i ON i.user_id = p.id
-- If you see "i.owner_id" then migration didn't apply!
-- If you see "i.user_id" then migration worked! ✅


-- Option B: Test with direct query (no function)
-- Replace 'PASTE_USER_ID' with actual user ID from profiles table

SELECT
  p.id,
  p.full_name,
  au.email,
  p.role,
  p.status,
  p.last_login,
  p.updated_at,
  p.created_at,  -- This should exist!
  COUNT(DISTINCT i.id) AS total_items,
  COUNT(DISTINCT CASE WHEN i.status = 'borrowed' THEN i.id END) AS borrowed_items,
  COUNT(DISTINCT CASE WHEN i.status = 'returned' THEN i.id END) AS returned_items,
  COUNT(DISTINCT CASE WHEN i.status = 'borrowed' AND i.due_date < CURRENT_DATE THEN i.id END) AS overdue_items
FROM public.profiles p
INNER JOIN auth.users au ON au.id = p.id
LEFT JOIN public.items i ON i.user_id = p.id  -- Using user_id, not owner_id
WHERE p.id = 'PASTE_USER_ID'
GROUP BY p.id, p.full_name, au.email, p.role, p.status, p.last_login, p.updated_at, p.created_at;

-- If this query returns data without error, then:
-- ✅ Migration worked!
-- ✅ Function structure is correct!
-- ✅ The only issue is permission in Flutter app

-- Next step: Test in Flutter app with admin login!
