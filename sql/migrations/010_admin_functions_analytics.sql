-- Migration: Add Admin Analytics Functions
-- Description: Create functions for dashboard statistics, user growth, item statistics, and top users
-- Dependencies: Requires migrations 001-009 (audit_logs, profiles, items tables)
-- Author: Admin Implementation Team
-- Date: 2025-12-02

-- ============================================================================
-- ANALYTICS FUNCTIONS FOR ADMIN DASHBOARD
-- ============================================================================
-- These functions provide aggregated statistics and analytics data for the
-- admin dashboard. All functions require admin privileges (checked via is_admin).
--
-- Functions:
-- 1. admin_get_dashboard_stats() - Quick stats for dashboard overview
-- 2. admin_get_user_growth(days) - User registration growth over time
-- 3. admin_get_item_statistics() - Item borrowing statistics
-- 4. admin_get_top_users(limit) - Users with most items
--
-- IMPORTANT SCHEMA NOTES:
-- - User creation timestamps: Use auth.users.created_at (NOT profiles.created_at)
-- - profiles table does NOT have created_at column
-- - profiles has: id, full_name, role, status, updated_at, last_login
-- - auth.users has: id, email, created_at (user registration date)
-- - Always JOIN auth.users when user creation date is needed
-- ============================================================================

-- ============================================================================
-- FUNCTION 1: admin_get_dashboard_stats
-- ============================================================================
-- Purpose: Get quick statistics for admin dashboard overview
-- Returns: Single row with key metrics
-- Usage: SELECT * FROM admin_get_dashboard_stats();
-- Note: new_users_today queries auth.users.created_at
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_dashboard_stats()
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
DECLARE
  v_admin_id UUID;
BEGIN
  -- Get admin user ID
  v_admin_id := auth.uid();

  -- Check if caller is admin
  IF NOT public.is_admin(v_admin_id) THEN
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

GRANT EXECUTE ON FUNCTION public.admin_get_dashboard_stats TO authenticated;

COMMENT ON FUNCTION public.admin_get_dashboard_stats IS
'Get quick statistics for admin dashboard. Returns user counts, item counts, storage info, and today''s activity. Admin only.';

-- ============================================================================
-- FUNCTION 2: admin_get_user_growth
-- ============================================================================
-- Purpose: Get user registration growth over specified number of days
-- Parameters: p_days - number of days to look back (default 30)
-- Returns: Date and count pairs for charting
-- Usage: SELECT * FROM admin_get_user_growth(30);
-- Note: Queries auth.users.created_at for user registration timestamps
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_user_growth(
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
DECLARE
  v_admin_id UUID;
BEGIN
  -- Get admin user ID
  v_admin_id := auth.uid();

  -- Check if caller is admin
  IF NOT public.is_admin(v_admin_id) THEN
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

GRANT EXECUTE ON FUNCTION public.admin_get_user_growth TO authenticated;

COMMENT ON FUNCTION public.admin_get_user_growth IS
'Get user registration growth over time. Returns daily new users and cumulative total. Admin only.';

-- ============================================================================
-- FUNCTION 3: admin_get_item_statistics
-- ============================================================================
-- Purpose: Get comprehensive item borrowing statistics
-- Returns: Single row with item metrics
-- Usage: SELECT * FROM admin_get_item_statistics();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_item_statistics()
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
  v_admin_id UUID;
  v_total BIGINT;
BEGIN
  -- Get admin user ID
  v_admin_id := auth.uid();

  -- Check if caller is admin
  IF NOT public.is_admin(v_admin_id) THEN
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

GRANT EXECUTE ON FUNCTION public.admin_get_item_statistics TO authenticated;

COMMENT ON FUNCTION public.admin_get_item_statistics IS
'Get comprehensive item statistics including counts, percentages, and loan duration metrics. Admin only.';

-- ============================================================================
-- FUNCTION 4: admin_get_top_users
-- ============================================================================
-- Purpose: Get users with most items (by total item count)
-- Parameters: p_limit - number of top users to return (default 10)
-- Returns: User info with item counts
-- Usage: SELECT * FROM admin_get_top_users(10);
-- Note: Returns auth.users.created_at (user registration date) as created_at
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_top_users(
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
DECLARE
  v_admin_id UUID;
BEGIN
  -- Get admin user ID
  v_admin_id := auth.uid();

  -- Check if caller is admin
  IF NOT public.is_admin(v_admin_id) THEN
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

GRANT EXECUTE ON FUNCTION public.admin_get_top_users TO authenticated;

COMMENT ON FUNCTION public.admin_get_top_users IS
'Get top users by item count. Returns user info with item statistics. Admin only.';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration 010 completed successfully';
  RAISE NOTICE 'Created admin analytics functions:';
  RAISE NOTICE '  - admin_get_dashboard_stats() → quick dashboard metrics';
  RAISE NOTICE '  - admin_get_user_growth(days) → user registration growth';
  RAISE NOTICE '  - admin_get_item_statistics() → item borrowing statistics';
  RAISE NOTICE '  - admin_get_top_users(limit) → top users by item count';
  RAISE NOTICE '';
  RAISE NOTICE '📊 All analytics functions are admin-only (SECURITY DEFINER)';
END $$;
