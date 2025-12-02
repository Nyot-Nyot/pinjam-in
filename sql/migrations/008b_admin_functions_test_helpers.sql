-- Migration: Add Test Helper Functions for Admin Functions
-- Purpose: Create test versions of admin functions that accept admin_user_id parameter
-- This is ONLY for testing in SQL Editor where auth.uid() returns NULL
-- DO NOT use these functions in production code!

-- ============================================================================
-- Drop existing test helper functions if they exist (to allow type changes)
-- ============================================================================

DROP FUNCTION IF EXISTS public.admin_get_all_users_test(UUID, INTEGER, INTEGER, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_get_user_details_test(UUID, UUID);
DROP FUNCTION IF EXISTS public.admin_update_user_role_test(UUID, UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_update_user_status_test(UUID, UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_delete_user_test(UUID, UUID, BOOLEAN, TEXT);

-- ============================================================================
-- TEST HELPER: admin_get_all_users_test
-- ============================================================================
-- Same as admin_get_all_users but with admin_user_id parameter for testing

CREATE OR REPLACE FUNCTION public.admin_get_all_users_test(
  p_admin_user_id UUID,  -- Added parameter for testing
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_role_filter TEXT DEFAULT NULL,
  p_status_filter TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email VARCHAR(255),  -- Changed from TEXT to match auth.users.email type
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
  -- Check if caller is admin using provided user_id instead of auth.uid()
  IF NOT public.is_admin(p_admin_user_id) THEN
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
    COUNT(i.id) as items_count,
    COUNT(i.id) FILTER (WHERE i.status = 'borrowed') as borrowed_items_count,
    COUNT(i.id) FILTER (WHERE i.status = 'returned') as returned_items_count
  FROM public.profiles p
  LEFT JOIN auth.users au ON p.id = au.id
  LEFT JOIN public.items i ON p.id = i.user_id
  WHERE
    (p_role_filter IS NULL OR p.role = p_role_filter)
    AND (p_status_filter IS NULL OR p.status = p_status_filter)
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

COMMENT ON FUNCTION public.admin_get_all_users_test IS
'TEST ONLY: Get all users with stats. Accepts admin_user_id parameter for SQL Editor testing.';

-- ============================================================================
-- TEST HELPER: admin_get_user_details_test
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_user_details_test(
  p_admin_user_id UUID,  -- Added parameter for testing
  p_user_id UUID
)
RETURNS TABLE (
  id UUID,
  email VARCHAR(255),  -- Changed from TEXT to match auth.users.email type
  full_name TEXT,
  role TEXT,
  status TEXT,
  last_login TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  total_items BIGINT,
  borrowed_items BIGINT,
  returned_items BIGINT,
  overdue_items BIGINT,
  storage_files_count BIGINT
)
SECURITY DEFINER
SET search_path = public, storage
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(p_admin_user_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view user details';
  END IF;

  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = p_user_id) THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    au.email,
    p.full_name,
    p.role,
    p.status,
    p.last_login,
    p.updated_at,
    COUNT(i.id) as total_items,
    COUNT(i.id) FILTER (WHERE i.status = 'borrowed') as borrowed_items,
    COUNT(i.id) FILTER (WHERE i.status = 'returned') as returned_items,
    COUNT(i.id) FILTER (
      WHERE i.status = 'borrowed'
      AND i.due_date IS NOT NULL
      AND i.due_date < CURRENT_DATE
    ) as overdue_items,
    (
      SELECT COUNT(*)
      FROM storage.objects
      WHERE owner_id::uuid = p_user_id
    ) as storage_files_count
  FROM public.profiles p
  LEFT JOIN auth.users au ON p.id = au.id
  LEFT JOIN public.items i ON p.id = i.user_id
  WHERE p.id = p_user_id
  GROUP BY p.id, au.email, p.full_name, p.role, p.status, p.last_login, p.updated_at;
END;
$$;

COMMENT ON FUNCTION public.admin_get_user_details_test IS
'TEST ONLY: Get detailed user info with metrics. Accepts admin_user_id parameter for SQL Editor testing.';

-- ============================================================================
-- TEST HELPER: admin_update_user_role_test
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_update_user_role_test(
  p_admin_user_id UUID,  -- Added parameter for testing
  p_user_id UUID,
  p_new_role TEXT
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  user_id UUID,
  old_role TEXT,
  new_role TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_old_role TEXT;
  v_user_exists BOOLEAN;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(p_admin_user_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can update user roles';
  END IF;

  -- Validate new role
  IF p_new_role NOT IN ('user', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %. Must be ''user'' or ''admin''', p_new_role;
  END IF;

  -- Check if user exists and get old role
  SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = p_user_id) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  SELECT role INTO v_old_role FROM public.profiles WHERE id = p_user_id;

  -- Prevent admin from demoting themselves
  IF p_user_id = p_admin_user_id AND p_new_role != 'admin' THEN
    RAISE EXCEPTION 'Cannot demote yourself from admin role';
  END IF;

  -- Update the role
  UPDATE public.profiles
  SET
    role = p_new_role,
    updated_at = NOW()
  WHERE id = p_user_id;

  -- Create audit log
  PERFORM public.create_admin_audit_log(
    p_admin_user_id,
    'update',
    'profiles',
    p_user_id,
    jsonb_build_object('role', v_old_role),
    jsonb_build_object('role', p_new_role),
    jsonb_build_object('action', 'role_update', 'old_role', v_old_role, 'new_role', p_new_role)
  );

  RETURN QUERY
  SELECT
    TRUE as success,
    'User role updated successfully' as message,
    p_user_id as user_id,
    v_old_role as old_role,
    p_new_role as new_role;
END;
$$;

COMMENT ON FUNCTION public.admin_update_user_role_test IS
'TEST ONLY: Update user role. Accepts admin_user_id parameter for SQL Editor testing.';

-- ============================================================================
-- TEST HELPER: admin_update_user_status_test
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_update_user_status_test(
  p_admin_user_id UUID,  -- Added parameter for testing
  p_user_id UUID,
  p_new_status TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  user_id UUID,
  old_status TEXT,
  new_status TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_old_status TEXT;
  v_user_exists BOOLEAN;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(p_admin_user_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can update user status';
  END IF;

  -- Validate new status
  IF p_new_status NOT IN ('active', 'inactive', 'suspended') THEN
    RAISE EXCEPTION 'Invalid status: %. Must be ''active'', ''inactive'', or ''suspended''', p_new_status;
  END IF;

  -- Check if user exists and get old status
  SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = p_user_id) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  SELECT status INTO v_old_status FROM public.profiles WHERE id = p_user_id;

  -- Prevent admin from deactivating themselves
  IF p_user_id = p_admin_user_id AND p_new_status != 'active' THEN
    RAISE EXCEPTION 'Cannot deactivate or suspend your own account';
  END IF;

  -- Update the status
  UPDATE public.profiles
  SET
    status = p_new_status,
    updated_at = NOW()
  WHERE id = p_user_id;

  -- Create audit log
  PERFORM public.create_admin_audit_log(
    p_admin_user_id,
    'update',
    'profiles',
    p_user_id,
    jsonb_build_object('status', v_old_status),
    jsonb_build_object('status', p_new_status),
    jsonb_build_object(
      'action', 'status_update',
      'old_status', v_old_status,
      'new_status', p_new_status,
      'reason', p_reason
    )
  );

  RETURN QUERY
  SELECT
    TRUE as success,
    'User status updated successfully' as message,
    p_user_id as user_id,
    v_old_status as old_status,
    p_new_status as new_status;
END;
$$;

COMMENT ON FUNCTION public.admin_update_user_status_test IS
'TEST ONLY: Update user status. Accepts admin_user_id parameter for SQL Editor testing.';

-- ============================================================================
-- TEST HELPER: admin_delete_user_test
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_delete_user_test(
  p_admin_user_id UUID,  -- Added parameter for testing
  p_user_id UUID,
  p_hard_delete BOOLEAN DEFAULT FALSE,
  p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  deleted_user_id UUID,
  delete_type TEXT,
  items_affected INT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_exists BOOLEAN;
  v_items_count INT;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(p_admin_user_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can delete users';
  END IF;

  -- Check if user exists
  SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = p_user_id) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Prevent admin from deleting themselves
  IF p_user_id = p_admin_user_id THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  -- Count user's items
  SELECT COUNT(*) INTO v_items_count FROM public.items WHERE user_id = p_user_id;

  IF p_hard_delete THEN
    -- Hard delete: Create audit log first, then cascade delete from auth.users
    PERFORM public.create_admin_audit_log(
      p_admin_user_id,
      'delete',
      'profiles',
      p_user_id,
      jsonb_build_object('hard_delete', true, 'items_count', v_items_count),
      NULL,
      jsonb_build_object(
        'action', 'hard_delete',
        'reason', p_reason,
        'items_affected', v_items_count
      )
    );

    -- Delete from auth.users will cascade to profiles and items
    DELETE FROM auth.users WHERE id = p_user_id;

    RETURN QUERY
    SELECT
      TRUE as success,
      'User permanently deleted' as message,
      p_user_id as deleted_user_id,
      'hard_delete' as delete_type,
      v_items_count as items_affected;
  ELSE
    -- Soft delete: Set status to inactive
    UPDATE public.profiles
    SET
      status = 'inactive',
      updated_at = NOW()
    WHERE id = p_user_id;

    -- Create audit log
    PERFORM public.create_admin_audit_log(
      p_admin_user_id,
      'update',
      'profiles',
      p_user_id,
      jsonb_build_object('status', 'active'),
      jsonb_build_object('status', 'inactive'),
      jsonb_build_object(
        'action', 'soft_delete',
        'reason', p_reason,
        'items_preserved', v_items_count
      )
    );

    RETURN QUERY
    SELECT
      TRUE as success,
      'User deactivated (soft delete)' as message,
      p_user_id as deleted_user_id,
      'soft_delete' as delete_type,
      v_items_count as items_affected;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.admin_delete_user_test IS
'TEST ONLY: Delete user (soft or hard). Accepts admin_user_id parameter for SQL Editor testing.';
