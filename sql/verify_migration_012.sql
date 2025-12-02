-- Verify Migration 012: Check if functions are correctly updated
-- Run this in Supabase SQL Editor to verify the migration

-- 1. Check admin_get_user_details function definition
SELECT
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'admin_get_user_details';

-- 2. Check admin_get_all_users function definition
SELECT
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'admin_get_all_users';

-- 3. Check if items table has user_id column (should be TRUE)
SELECT EXISTS (
  SELECT 1
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'items'
    AND column_name = 'user_id'
) as has_user_id_column;

-- 4. Check if items table has owner_id column (should be FALSE)
SELECT EXISTS (
  SELECT 1
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'items'
    AND column_name = 'owner_id'
) as has_owner_id_column;

-- 5. Test admin_get_user_details with a real user ID
-- Replace 'YOUR_USER_ID' with actual user ID from profiles table
DO $$
DECLARE
  test_user_id UUID;
BEGIN
  -- Get first user ID for testing
  SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

  IF test_user_id IS NOT NULL THEN
    RAISE NOTICE 'Testing admin_get_user_details with user_id: %', test_user_id;

    -- Try to call the function (will fail if there's still an error)
    PERFORM * FROM public.admin_get_user_details(test_user_id);

    RAISE NOTICE '✅ Function admin_get_user_details works correctly!';
  ELSE
    RAISE NOTICE '⚠️ No users found in profiles table for testing';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '❌ Error calling admin_get_user_details: %', SQLERRM;
END $$;
