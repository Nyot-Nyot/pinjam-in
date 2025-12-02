-- Migration: Admin User Management Functions
-- Filename: sql/migrations/008_admin_functions_users.sql
-- Purpose: Create functions for admin user management operations
--
-- Functions included:
-- 1. admin_get_all_users() - List all users with stats
-- 2. admin_get_user_details(user_id) - Get detailed user info
-- 3. admin_update_user_role(user_id, new_role) - Update user role
-- 4. admin_update_user_status(user_id, new_status) - Update user status
-- 5. admin_delete_user(user_id, hard_delete) - Delete user (soft or hard)
-- 6. create_admin_audit_log() - Helper for audit logging

BEGIN;

-- ============================================================================
-- HELPER FUNCTION: Create Admin Audit Log
-- ============================================================================
-- Purpose: Reusable function for creating audit logs from admin functions
-- This ensures consistent audit logging across all admin operations

CREATE OR REPLACE FUNCTION public.create_admin_audit_log(
  p_admin_user_id UUID,
  p_action_type TEXT,
  p_table_name TEXT,
  p_record_id UUID,
  p_old_values JSONB DEFAULT NULL,
  p_new_values JSONB DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_audit_id UUID;
BEGIN
  -- Insert audit log
  INSERT INTO public.audit_logs (
    admin_user_id,
    action_type,
    table_name,
    record_id,
    old_values,
    new_values,
    metadata,
    created_at
  ) VALUES (
    p_admin_user_id,
    p_action_type,
    p_table_name,
    p_record_id,
    p_old_values,
    p_new_values,
    COALESCE(p_metadata, jsonb_build_object('timestamp', NOW())),
    NOW()
  )
  RETURNING id INTO v_audit_id;

  RETURN v_audit_id;
END;
$$;

-- Grant execute to authenticated users (will be called by other admin functions)
GRANT EXECUTE ON FUNCTION public.create_admin_audit_log TO authenticated;

COMMENT ON FUNCTION public.create_admin_audit_log IS
'Helper function to create audit logs. Used by admin functions to ensure consistent audit trail.';

-- ============================================================================
-- FUNCTION 1: Get All Users
-- ============================================================================
-- Purpose: Retrieve list of all users with basic stats
-- Returns: Table with user info and item counts

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
    COUNT(i.id) as items_count,
    COUNT(CASE WHEN i.status = 'borrowed' THEN 1 END) as borrowed_items_count,
    COUNT(CASE WHEN i.status = 'returned' THEN 1 END) as returned_items_count
  FROM public.profiles p
  LEFT JOIN auth.users au ON au.id = p.id
  LEFT JOIN public.items i ON i.user_id = p.id
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

GRANT EXECUTE ON FUNCTION public.admin_get_all_users TO authenticated;

COMMENT ON FUNCTION public.admin_get_all_users IS
'Get list of all users with stats. Supports filtering by role, status, and search. Admin only.';

-- ============================================================================
-- FUNCTION 2: Get User Details
-- ============================================================================
-- Purpose: Get complete details for a specific user including activity metrics

CREATE OR REPLACE FUNCTION public.admin_get_user_details(p_user_id UUID)
RETURNS TABLE (
  -- Profile fields
  id UUID,
  full_name TEXT,
  email VARCHAR(255),  -- Changed from TEXT to match auth.users.email type
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
    -- Profile fields
    p.id,
    p.full_name,
    au.email,
    p.role,
    p.status,
    p.last_login,
    p.updated_at,
    au.created_at,
    -- Activity metrics
    COUNT(i.id) as total_items,
    COUNT(CASE WHEN i.status = 'borrowed' THEN 1 END) as borrowed_items,
    COUNT(CASE WHEN i.status = 'returned' THEN 1 END) as returned_items,
    COUNT(CASE
      WHEN i.status = 'borrowed'
      AND i.due_date IS NOT NULL
      AND i.due_date < CURRENT_DATE
      THEN 1
    END) as overdue_items,
    -- Storage metrics (count files in storage bucket)
    (
      SELECT COUNT(*)
      FROM storage.objects so
      WHERE so.bucket_id = 'item-images'
      AND so.owner = p_user_id::TEXT
    ) as storage_files_count
  FROM public.profiles p
  LEFT JOIN auth.users au ON au.id = p.id
  LEFT JOIN public.items i ON i.user_id = p.id
  WHERE p.id = p_user_id
  GROUP BY p.id, p.full_name, au.email, p.role, p.status, p.last_login, p.updated_at, au.created_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_user_details TO authenticated;

COMMENT ON FUNCTION public.admin_get_user_details IS
'Get detailed information for a specific user including activity and storage metrics. Admin only.';

-- ============================================================================
-- FUNCTION 3: Update User Role
-- ============================================================================
-- Purpose: Update user role with validation and audit logging

CREATE OR REPLACE FUNCTION public.admin_update_user_role(
  p_user_id UUID,
  p_new_role TEXT
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  role TEXT,
  updated_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_old_role TEXT;
  v_audit_id UUID;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can update user roles';
  END IF;

  -- Validate role value
  IF p_new_role NOT IN ('user', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %. Must be ''user'' or ''admin''', p_new_role;
  END IF;

  -- Check if user exists and get old role
  SELECT profiles.role INTO v_old_role
  FROM public.profiles
  WHERE profiles.id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;

  -- Prevent users from removing their own admin role
  IF p_user_id = auth.uid() AND v_old_role = 'admin' AND p_new_role != 'admin' THEN
    RAISE EXCEPTION 'Cannot remove your own admin role';
  END IF;

  -- Update role
  UPDATE public.profiles
  SET
    role = p_new_role,
    updated_at = NOW()
  WHERE profiles.id = p_user_id;

  -- Create audit log
  v_audit_id := public.create_admin_audit_log(
    auth.uid(),
    'update',
    'profiles',
    p_user_id,
    jsonb_build_object('role', v_old_role),
    jsonb_build_object('role', p_new_role),
    jsonb_build_object(
      'action', 'role_change',
      'old_role', v_old_role,
      'new_role', p_new_role
    )
  );

  -- Return updated profile
  RETURN QUERY
  SELECT
    profiles.id,
    profiles.full_name,
    profiles.role,
    profiles.updated_at
  FROM public.profiles
  WHERE profiles.id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_user_role TO authenticated;

COMMENT ON FUNCTION public.admin_update_user_role IS
'Update user role with validation and audit logging. Prevents self-demotion. Admin only.';

-- ============================================================================
-- FUNCTION 4: Update User Status
-- ============================================================================
-- Purpose: Update user status with validation and audit logging

CREATE OR REPLACE FUNCTION public.admin_update_user_status(
  p_user_id UUID,
  p_new_status TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  status TEXT,
  updated_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_old_status TEXT;
  v_audit_id UUID;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can update user status';
  END IF;

  -- Validate status value
  IF p_new_status NOT IN ('active', 'inactive', 'suspended') THEN
    RAISE EXCEPTION 'Invalid status: %. Must be ''active'', ''inactive'', or ''suspended''', p_new_status;
  END IF;

  -- Check if user exists and get old status
  SELECT profiles.status INTO v_old_status
  FROM public.profiles
  WHERE profiles.id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;

  -- Prevent disabling own account
  IF p_user_id = auth.uid() AND p_new_status != 'active' THEN
    RAISE EXCEPTION 'Cannot deactivate or suspend your own account';
  END IF;

  -- Update status
  UPDATE public.profiles
  SET
    status = p_new_status,
    updated_at = NOW()
  WHERE profiles.id = p_user_id;

  -- Create audit log
  v_audit_id := public.create_admin_audit_log(
    auth.uid(),
    'update',
    'profiles',
    p_user_id,
    jsonb_build_object('status', v_old_status),
    jsonb_build_object('status', p_new_status),
    jsonb_build_object(
      'action', 'status_change',
      'old_status', v_old_status,
      'new_status', p_new_status,
      'reason', p_reason
    )
  );

  -- Return updated profile
  RETURN QUERY
  SELECT
    profiles.id,
    profiles.full_name,
    profiles.status,
    profiles.updated_at
  FROM public.profiles
  WHERE profiles.id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_user_status TO authenticated;

COMMENT ON FUNCTION public.admin_update_user_status IS
'Update user status with validation and audit logging. Prevents self-deactivation. Admin only.';

-- ============================================================================
-- FUNCTION 5: Delete User
-- ============================================================================
-- Purpose: Delete user (soft or hard) with proper cleanup and audit logging

CREATE OR REPLACE FUNCTION public.admin_delete_user(
  p_user_id UUID,
  p_hard_delete BOOLEAN DEFAULT FALSE,
  p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  deleted_items_count INT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_data JSONB;
  v_items_count INT;
  v_audit_id UUID;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can delete users';
  END IF;

  -- Prevent self-deletion
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  -- Check if user exists and get data for audit
  SELECT row_to_json(profiles.*) INTO v_user_data
  FROM public.profiles
  WHERE profiles.id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;

  -- Get items count
  SELECT COUNT(*) INTO v_items_count
  FROM public.items
  WHERE user_id = p_user_id;

  IF p_hard_delete THEN
    -- Hard delete: Remove user completely
    -- This will CASCADE delete items, audit logs, etc. (defined in schema)

    -- Create audit log BEFORE deletion
    v_audit_id := public.create_admin_audit_log(
      auth.uid(),
      'delete',
      'profiles',
      p_user_id,
      v_user_data,
      NULL,
      jsonb_build_object(
        'action', 'hard_delete',
        'reason', p_reason,
        'items_count', v_items_count
      )
    );

    -- Delete from auth.users (CASCADE will handle profiles and related data)
    DELETE FROM auth.users WHERE id = p_user_id;

    RETURN QUERY SELECT
      TRUE as success,
      format('User permanently deleted. %s items also deleted.', v_items_count) as message,
      v_items_count as deleted_items_count;

  ELSE
    -- Soft delete: Set status to inactive
    UPDATE public.profiles
    SET
      status = 'inactive',
      updated_at = NOW()
    WHERE id = p_user_id;

    -- Create audit log
    v_audit_id := public.create_admin_audit_log(
      auth.uid(),
      'update',
      'profiles',
      p_user_id,
      jsonb_build_object('status', v_user_data->>'status'),
      jsonb_build_object('status', 'inactive'),
      jsonb_build_object(
        'action', 'soft_delete',
        'reason', p_reason,
        'items_count', v_items_count
      )
    );

    RETURN QUERY SELECT
      TRUE as success,
      format('User deactivated (soft delete). %s items preserved.', v_items_count) as message,
      0 as deleted_items_count;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_delete_user TO authenticated;

COMMENT ON FUNCTION public.admin_delete_user IS
'Delete user (soft or hard). Soft delete sets status to inactive. Hard delete permanently removes user and CASCADE deletes items. Admin only.';

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- After running this migration, test with these queries:

-- 1. Test get all users
-- SELECT * FROM admin_get_all_users(50, 0, NULL, NULL, NULL);

-- 2. Test get user details (replace with actual user ID)
-- SELECT * FROM admin_get_user_details('your-user-id-here');

-- 3. Test update role (replace with actual user ID)
-- SELECT * FROM admin_update_user_role('user-id', 'admin');

-- 4. Test update status (replace with actual user ID)
-- SELECT * FROM admin_update_user_status('user-id', 'suspended', 'Testing suspension');

-- 5. Test soft delete (replace with actual user ID)
-- SELECT * FROM admin_delete_user('user-id', FALSE, 'Test soft delete');

-- 6. Check audit logs were created
-- SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 10;
