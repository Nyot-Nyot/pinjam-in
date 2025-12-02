-- Migration: Add Test Helper Functions for Admin Analytics Functions
-- Purpose: Create test versions of admin analytics functions that accept admin_user_id parameter
-- This is ONLY for testing in SQL Editor where auth.uid() returns NULL
-- DO NOT use these functions in production code!

-- ============================================================================
-- Drop existing test helper functions if they exist
-- ============================================================================

DROP FUNCTION IF EXISTS public.admin_get_dashboard_stats_test(UUID);
DROP FUNCTION IF EXISTS public.admin_get_user_growth_test(UUID, INTEGER);
DROP FUNCTION IF EXISTS public.admin_get_item_statistics_test(UUID);
DROP FUNCTION IF EXISTS public.admin_get_top_users_test(UUID, INTEGER);

-- ============================================================================
-- TEST HELPER: admin_get_dashboard_stats_test
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_dashboard_stats_test(
  p_admin_user_id UUID  -- Added parameter for testing
)
RETURNS TABLE (
  total_users BIGINT,
  active_users BIGINT,
  inactive_users BIGINT,
  admin_users BIGINT,
  total_items BIGINT,
  borrowed_items BIGINT,
  returned_items BIGINT,
  overdue_items BIGINT,
  total_storage_files BIGINT,
  new_users_today BIGINT,
  new_items_today BIGINT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if caller is admin (using parameter instead of auth.uid())
  IF NOT public.is_admin(p_admin_user_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view dashboard statistics';
  END IF;

  -- Return aggregated statistics
  RETURN QUERY
  SELECT
    -- User statistics
    (SELECT COUNT(*) FROM public.profiles)::BIGINT AS total_users,
    (SELECT COUNT(*) FROM public.profiles WHERE status = 'active')::BIGINT AS active_users,
    (SELECT COUNT(*) FROM public.profiles WHERE status = 'inactive')::BIGINT AS inactive_users,
    (SELECT COUNT(*) FROM public.profiles WHERE role = 'admin')::BIGINT AS admin_users,

    -- Item statistics
    (SELECT COUNT(*) FROM public.items)::BIGINT AS total_items,
    (SELECT COUNT(*) FROM public.items WHERE status = 'borrowed')::BIGINT AS borrowed_items,
    (SELECT COUNT(*) FROM public.items WHERE status = 'returned')::BIGINT AS returned_items,
    (SELECT COUNT(*) FROM public.items WHERE status = 'borrowed' AND return_date < CURRENT_DATE)::BIGINT AS overdue_items,

    -- Storage statistics (count files in items)
    (SELECT COUNT(*) FROM public.items WHERE photo_url IS NOT NULL)::BIGINT AS total_storage_files,

    -- Today's activity
    (SELECT COUNT(*) FROM auth.users WHERE created_at >= CURRENT_DATE)::BIGINT AS new_users_today,
    (SELECT COUNT(*) FROM public.items WHERE created_at >= CURRENT_DATE)::BIGINT AS new_items_today;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_dashboard_stats_test TO authenticated;

COMMENT ON FUNCTION public.admin_get_dashboard_stats_test IS
'TEST HELPER: Get dashboard statistics. For SQL Editor testing only.';

-- ============================================================================
-- TEST HELPER: admin_get_user_growth_test
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_user_growth_test(
  p_admin_user_id UUID,  -- Added parameter for testing
  p_days INTEGER DEFAULT 30
)
RETURNS TABLE (
  date DATE,
  new_users BIGINT,
  cumulative_users BIGINT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if caller is admin (using parameter instead of auth.uid())
  IF NOT public.is_admin(p_admin_user_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view user growth statistics';
  END IF;

  -- Validate days parameter
  IF p_days <= 0 OR p_days > 365 THEN
    RAISE EXCEPTION 'Invalid days parameter: %. Must be between 1 and 365', p_days;
  END IF;

  -- Return user growth data
  RETURN QUERY
  WITH date_series AS (
    -- Generate series of dates
    SELECT
      date_val::DATE AS date
    FROM generate_series(
      CURRENT_DATE - (p_days - 1),
      CURRENT_DATE,
      '1 day'::INTERVAL
    ) AS date_val
  ),
  daily_users AS (
    -- Count new users per day
    SELECT
      DATE(created_at) AS date,
      COUNT(*)::BIGINT AS new_users
    FROM auth.users
    WHERE created_at >= CURRENT_DATE - (p_days - 1)
    GROUP BY DATE(created_at)
  )
  SELECT
    ds.date,
    COALESCE(du.new_users, 0)::BIGINT AS new_users,
    (
      SELECT COUNT(*)::BIGINT
      FROM auth.users
      WHERE DATE(created_at) <= ds.date
    ) AS cumulative_users
  FROM date_series ds
  LEFT JOIN daily_users du ON ds.date = du.date
  ORDER BY ds.date;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_user_growth_test TO authenticated;

COMMENT ON FUNCTION public.admin_get_user_growth_test IS
'TEST HELPER: Get user growth over time. For SQL Editor testing only.';

-- ============================================================================
-- TEST HELPER: admin_get_item_statistics_test
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_item_statistics_test(
  p_admin_user_id UUID  -- Added parameter for testing
)
RETURNS TABLE (
  total_items BIGINT,
  borrowed_items BIGINT,
  returned_items BIGINT,
  overdue_items BIGINT,
  borrowed_percentage NUMERIC,
  returned_percentage NUMERIC,
  overdue_percentage NUMERIC,
  avg_loan_duration_days NUMERIC,
  total_completed_loans BIGINT,
  items_never_returned BIGINT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_total BIGINT;
BEGIN
  -- Check if caller is admin (using parameter instead of auth.uid())
  IF NOT public.is_admin(p_admin_user_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view item statistics';
  END IF;

  -- Get total items count
  SELECT COUNT(*) INTO v_total FROM public.items;

  -- Return item statistics
  RETURN QUERY
  SELECT
    v_total AS total_items,
    (SELECT COUNT(*) FROM public.items WHERE status = 'borrowed')::BIGINT AS borrowed_items,
    (SELECT COUNT(*) FROM public.items WHERE status = 'returned')::BIGINT AS returned_items,
    (SELECT COUNT(*) FROM public.items WHERE status = 'borrowed' AND return_date < CURRENT_DATE)::BIGINT AS overdue_items,

    -- Percentages
    CASE WHEN v_total > 0 THEN
      ROUND((SELECT COUNT(*)::NUMERIC FROM public.items WHERE status = 'borrowed') * 100.0 / v_total, 2)
    ELSE 0 END AS borrowed_percentage,

    CASE WHEN v_total > 0 THEN
      ROUND((SELECT COUNT(*)::NUMERIC FROM public.items WHERE status = 'returned') * 100.0 / v_total, 2)
    ELSE 0 END AS returned_percentage,

    CASE WHEN v_total > 0 THEN
      ROUND((SELECT COUNT(*)::NUMERIC FROM public.items WHERE status = 'borrowed' AND return_date < CURRENT_DATE) * 100.0 / v_total, 2)
    ELSE 0 END AS overdue_percentage,

    -- Average loan duration (for returned items only)
    (
      SELECT ROUND(AVG(EXTRACT(DAY FROM (return_date - borrow_date)))::NUMERIC, 1)
      FROM public.items
      WHERE status = 'returned'
        AND return_date IS NOT NULL
        AND borrow_date IS NOT NULL
    ) AS avg_loan_duration_days,

    -- Total completed loans (items that have been returned)
    (SELECT COUNT(*) FROM public.items WHERE status = 'returned')::BIGINT AS total_completed_loans,

    -- Items borrowed but never returned (overdue more than 90 days)
    (
      SELECT COUNT(*)
      FROM public.items
      WHERE status = 'borrowed'
        AND return_date < CURRENT_DATE - INTERVAL '90 days'
    )::BIGINT AS items_never_returned;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_item_statistics_test TO authenticated;

COMMENT ON FUNCTION public.admin_get_item_statistics_test IS
'TEST HELPER: Get item statistics. For SQL Editor testing only.';

-- ============================================================================
-- TEST HELPER: admin_get_top_users_test
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_top_users_test(
  p_admin_user_id UUID,  -- Added parameter for testing
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  email VARCHAR(255),
  role TEXT,
  status TEXT,
  total_items BIGINT,
  borrowed_items BIGINT,
  returned_items BIGINT,
  overdue_items BIGINT,
  created_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if caller is admin (using parameter instead of auth.uid())
  IF NOT public.is_admin(p_admin_user_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view top users';
  END IF;

  -- Validate limit parameter
  IF p_limit <= 0 OR p_limit > 100 THEN
    RAISE EXCEPTION 'Invalid limit parameter: %. Must be between 1 and 100', p_limit;
  END IF;

  -- Return top users by item count
  RETURN QUERY
  SELECT
    p.id AS user_id,
    p.full_name,
    au.email,
    p.role,
    p.status,
    COUNT(i.id)::BIGINT AS total_items,
    COUNT(CASE WHEN i.status = 'borrowed' THEN 1 END)::BIGINT AS borrowed_items,
    COUNT(CASE WHEN i.status = 'returned' THEN 1 END)::BIGINT AS returned_items,
    COUNT(CASE WHEN i.status = 'borrowed' AND i.return_date < CURRENT_DATE THEN 1 END)::BIGINT AS overdue_items,
    au.created_at
  FROM public.profiles p
  INNER JOIN auth.users au ON au.id = p.id
  LEFT JOIN public.items i ON i.user_id = p.id
  GROUP BY p.id, p.full_name, au.email, p.role, p.status, au.created_at
  HAVING COUNT(i.id) > 0
  ORDER BY total_items DESC, p.full_name ASC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_top_users_test TO authenticated;

COMMENT ON FUNCTION public.admin_get_top_users_test IS
'TEST HELPER: Get top users by item count. For SQL Editor testing only.';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration 010b completed successfully';
  RAISE NOTICE 'Created test helper functions:';
  RAISE NOTICE '  - admin_get_dashboard_stats_test(admin_id)';
  RAISE NOTICE '  - admin_get_user_growth_test(admin_id, days)';
  RAISE NOTICE '  - admin_get_item_statistics_test(admin_id)';
  RAISE NOTICE '  - admin_get_top_users_test(admin_id, limit)';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  These are TEST HELPERS only - use for SQL Editor testing';
END $$;
