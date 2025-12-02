-- Migration 012: Fix owner_id to user_id in admin functions
-- Date: 2025-12-02
-- Issue: admin_get_all_users and admin_get_user_details reference i.owner_id
--        but items table uses i.user_id column
-- Fix: Replace owner_id with user_id in both functions

-- ============================================================================
-- 1. Fix admin_get_all_users
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_all_users(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_role_filter TEXT DEFAULT NULL,
  p_status_filter TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email VARCHAR(255),
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
    -- Count returned items (status = 'returned')
    COALESCE(COUNT(DISTINCT CASE WHEN i.status = 'returned' THEN i.id END), 0) AS returned_items_count
  FROM public.profiles p
  INNER JOIN auth.users au ON au.id = p.id
  LEFT JOIN public.items i ON i.user_id = p.id  -- FIXED: owner_id -> user_id
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
'Get list of all users with stats. Supports filtering by role, status, and search. Admin only. FIXED: user_id reference';

-- ============================================================================
-- 2. Fix admin_get_user_details
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_user_details(
  p_user_id UUID
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email VARCHAR(255),
  role TEXT,
  status TEXT,
  last_login TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  total_items BIGINT,
  borrowed_items BIGINT,
  returned_items BIGINT,
  overdue_items BIGINT,
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
    -- Returned items
    COALESCE(COUNT(DISTINCT CASE WHEN i.status = 'returned' THEN i.id END), 0) AS returned_items,
    -- Overdue items (borrowed with due_date in past)
    COALESCE(COUNT(DISTINCT CASE
      WHEN i.status = 'borrowed' AND i.due_date < CURRENT_DATE
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
  LEFT JOIN public.items i ON i.user_id = p.id  -- FIXED: owner_id -> user_id
  WHERE p.id = p_user_id
  GROUP BY p.id, p.full_name, au.email, p.role, p.status, p.last_login, p.updated_at, p.created_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_user_details TO authenticated;

COMMENT ON FUNCTION public.admin_get_user_details IS
'Get detailed user information with activity and storage metrics. Admin only. FIXED: user_id reference';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration 012 completed successfully';
  RAISE NOTICE 'Fixed column references:';
  RAISE NOTICE '  - admin_get_all_users: i.owner_id -> i.user_id';
  RAISE NOTICE '  - admin_get_user_details: i.owner_id -> i.user_id';
  RAISE NOTICE '';
  RAISE NOTICE 'Note: Items table uses user_id, not owner_id';
END $$;
