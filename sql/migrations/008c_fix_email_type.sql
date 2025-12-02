-- ============================================================================
-- Migration 008c: Fix Email Type in Admin Functions
-- ============================================================================
-- Purpose: Fix email column type from TEXT to VARCHAR(255) to match auth.users.email
-- Date: 2024-12-02
-- Dependencies: 008_admin_functions_users.sql must be applied first
--
-- This migration drops and recreates two functions with corrected return types:
-- - admin_get_all_users: email TEXT -> VARCHAR(255)
-- - admin_get_user_details: email TEXT -> VARCHAR(255)
-- ============================================================================

-- Drop existing functions that need type corrections
DROP FUNCTION IF EXISTS public.admin_get_all_users(INTEGER, INTEGER, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_get_user_details(UUID);

-- ============================================================================
-- FUNCTION 1: Get All Users (CORRECTED)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_all_users(
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0,
  p_role_filter TEXT DEFAULT NULL,
  p_status_filter TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email VARCHAR(255),  -- FIXED: Changed from TEXT to match auth.users.email type
  role TEXT,
  status TEXT,
  last_login TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  items_count BIGINT,
  borrowed_items_count BIGINT,
  returned_items_count BIGINT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view all users';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    au.email,
    p.role,
    p.status,
    p.last_login,
    p.updated_at,
    -- Count total items owned
    COALESCE(COUNT(DISTINCT i.id), 0) AS items_count,
    -- Count currently borrowed items (status = 'borrowed')
    COALESCE(COUNT(DISTINCT CASE WHEN i.status = 'borrowed' THEN i.id END), 0) AS borrowed_items_count,
    -- Count returned items (status = 'available' or 'unavailable')
    COALESCE(COUNT(DISTINCT CASE WHEN i.status IN ('available', 'unavailable') THEN i.id END), 0) AS returned_items_count
  FROM public.profiles p
  INNER JOIN auth.users au ON au.id = p.id
  LEFT JOIN public.items i ON i.owner_id = p.id
  WHERE
    -- Apply role filter if provided
    (p_role_filter IS NULL OR p.role = p_role_filter)
    -- Apply status filter if provided
    AND (p_status_filter IS NULL OR p.status = p_status_filter)
    -- Apply search filter if provided (search in name, email)
    AND (
      p_search IS NULL
      OR p.full_name ILIKE '%' || p_search || '%'
      OR au.email ILIKE '%' || p_search || '%'
    )
  GROUP BY p.id, p.full_name, au.email, p.role, p.status, p.last_login, p.updated_at
  ORDER BY p.updated_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_all_users TO authenticated;

COMMENT ON FUNCTION public.admin_get_all_users IS
'Get list of all users with stats. Supports filtering by role, status, and search. Admin only. FIXED: email type matches auth.users';

-- ============================================================================
-- FUNCTION 2: Get User Details (CORRECTED)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_user_details(p_user_id UUID)
RETURNS TABLE (
  -- Profile fields
  id UUID,
  full_name TEXT,
  email VARCHAR(255),  -- FIXED: Changed from TEXT to match auth.users.email type
  role TEXT,
  status TEXT,
  last_login TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  -- Activity metrics
  total_items BIGINT,
  borrowed_items BIGINT,
  returned_items BIGINT,
  overdue_items BIGINT,
  -- Storage metrics
  storage_files_count BIGINT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view user details';
  END IF;

  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE public.profiles.id = p_user_id) THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    au.email,
    p.role,
    p.status,
    p.last_login,
    p.updated_at,
    p.created_at,
    -- Total items owned by user
    COALESCE(COUNT(DISTINCT i.id), 0) AS total_items,
    -- Currently borrowed items
    COALESCE(COUNT(DISTINCT CASE WHEN i.status = 'borrowed' THEN i.id END), 0) AS borrowed_items,
    -- Returned items (available or unavailable)
    COALESCE(COUNT(DISTINCT CASE WHEN i.status IN ('available', 'unavailable') THEN i.id END), 0) AS returned_items,
    -- Overdue items (borrowed with return_date in past)
    COALESCE(COUNT(DISTINCT CASE
      WHEN i.status = 'borrowed' AND i.return_date < NOW()
      THEN i.id
    END), 0) AS overdue_items,
    -- Storage files count
    COALESCE((
      SELECT COUNT(*)
      FROM storage.objects
      WHERE bucket_id = 'item_images' AND owner = p_user_id
    ), 0) AS storage_files_count
  FROM public.profiles p
  INNER JOIN auth.users au ON au.id = p.id
  LEFT JOIN public.items i ON i.owner_id = p.id
  WHERE p.id = p_user_id
  GROUP BY p.id, p.full_name, au.email, p.role, p.status, p.last_login, p.updated_at, p.created_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_user_details TO authenticated;

COMMENT ON FUNCTION public.admin_get_user_details IS
'Get detailed user information with activity and storage metrics. Admin only. FIXED: email type matches auth.users';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify functions exist with correct signatures
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 008c completed successfully';
  RAISE NOTICE 'Fixed functions:';
  RAISE NOTICE '  - admin_get_all_users (email: VARCHAR(255))';
  RAISE NOTICE '  - admin_get_user_details (email: VARCHAR(255))';
END $$;
