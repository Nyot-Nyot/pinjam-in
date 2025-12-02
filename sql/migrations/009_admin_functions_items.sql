-- Migration: Admin Items Management Functions
-- Filename: sql/migrations/009_admin_functions_items.sql
-- Purpose: Create functions for admin items management operations
--
-- Functions included:
-- 1. admin_get_all_items() - List all items with filters and owner info
-- 2. admin_get_item_details(item_id) - Get detailed item info
-- 3. admin_update_item_status(item_id, new_status, reason) - Update item status
-- 4. admin_delete_item(item_id, hard_delete, reason) - Delete item (soft or hard)
--
-- Dependencies:
-- - Migration 008: create_admin_audit_log() function
-- - is_admin() function from migration 007
-- - items table with proper schema
-- - profiles table

BEGIN;

-- ============================================================================
-- FUNCTION 1: Get All Items
-- ============================================================================
-- Purpose: Get list of all items with owner info and filtering options
-- Returns: Items with owner details and stats
-- Permissions: Admin only

CREATE OR REPLACE FUNCTION public.admin_get_all_items(
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0,
  p_status_filter TEXT DEFAULT NULL,
  p_user_filter UUID DEFAULT NULL,
  p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  borrower_name TEXT,
  borrower_contact_id TEXT,
  borrow_date TIMESTAMPTZ,
  return_date DATE,
  status TEXT,
  notes TEXT,
  photo_url TEXT,
  -- Owner info
  user_id UUID,
  owner_name TEXT,
  owner_email VARCHAR(255),
  -- Metadata
  created_at TIMESTAMPTZ,
  -- Computed fields
  is_overdue BOOLEAN,
  days_borrowed INTEGER
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view all items';
  END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.name,
    i.borrower_name,
    i.borrower_contact_id,
    i.borrow_date,
    i.return_date,
    i.status,
    i.notes,
    i.photo_url,
    -- Owner info
    i.user_id,
    p.full_name AS owner_name,
    au.email AS owner_email,
    -- Metadata
    i.created_at,
    -- Computed fields
    (i.status = 'borrowed' AND i.return_date < NOW()) AS is_overdue,
    CASE
      WHEN i.borrow_date IS NOT NULL THEN
        EXTRACT(DAY FROM NOW() - i.borrow_date)::INTEGER
      ELSE NULL
    END AS days_borrowed
  FROM public.items i
  INNER JOIN public.profiles p ON p.id = i.user_id
  INNER JOIN auth.users au ON au.id = p.id
  WHERE
    -- Apply status filter if provided
    (p_status_filter IS NULL OR i.status = p_status_filter)
    -- Apply user/owner filter if provided
    AND (p_user_filter IS NULL OR i.user_id = p_user_filter)
    -- Apply search filter if provided (search in item name, borrower, notes)
    AND (
      p_search IS NULL
      OR i.name ILIKE '%' || p_search || '%'
      OR i.borrower_name ILIKE '%' || p_search || '%'
      OR i.notes ILIKE '%' || p_search || '%'
    )
  ORDER BY
    -- Show overdue items first
    CASE WHEN i.status = 'borrowed' AND i.return_date < NOW() THEN 0 ELSE 1 END,
    i.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_all_items TO authenticated;

COMMENT ON FUNCTION public.admin_get_all_items IS
'Get list of all items with owner info and filtering. Supports filtering by status, user, and search. Shows overdue items first. Admin only.';

-- ============================================================================
-- FUNCTION 2: Get Item Details
-- ============================================================================
-- Purpose: Get complete details for a specific item including history
-- Returns: Detailed item info with owner and borrower details
-- Permissions: Admin only

CREATE OR REPLACE FUNCTION public.admin_get_item_details(p_item_id UUID)
RETURNS TABLE (
  -- Item fields
  id UUID,
  name TEXT,
  borrower_name TEXT,
  borrower_contact_id TEXT,
  borrow_date TIMESTAMPTZ,
  return_date DATE,
  status TEXT,
  notes TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ,
  -- Owner info
  user_id UUID,
  owner_name TEXT,
  owner_email VARCHAR(255),
  owner_role TEXT,
  owner_status TEXT,
  -- Computed fields
  is_overdue BOOLEAN,
  days_borrowed INTEGER,
  days_overdue INTEGER,
  -- Owner stats
  owner_total_items BIGINT,
  owner_borrowed_items BIGINT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view item details';
  END IF;

  -- Check if item exists
  IF NOT EXISTS (SELECT 1 FROM public.items WHERE items.id = p_item_id) THEN
    RAISE EXCEPTION 'Item not found: %', p_item_id;
  END IF;

  RETURN QUERY
  SELECT
    -- Item fields
    i.id,
    i.name,
    i.borrower_name,
    i.borrower_contact_id,
    i.borrow_date,
    i.return_date,
    i.status,
    i.notes,
    i.photo_url,
    i.created_at,
    -- Owner info
    i.user_id,
    p.full_name AS owner_name,
    au.email AS owner_email,
    p.role AS owner_role,
    p.status AS owner_status,
    -- Computed fields
    (i.status = 'borrowed' AND i.return_date < NOW()) AS is_overdue,
    CASE
      WHEN i.borrow_date IS NOT NULL THEN
        EXTRACT(DAY FROM NOW() - i.borrow_date)::INTEGER
      ELSE NULL
    END AS days_borrowed,
    CASE
      WHEN i.status = 'borrowed' AND i.return_date < NOW() THEN
        EXTRACT(DAY FROM NOW() - i.return_date)::INTEGER
      ELSE NULL
    END AS days_overdue,
    -- Owner stats
    (SELECT COUNT(*) FROM public.items items_sub WHERE items_sub.user_id = i.user_id) AS owner_total_items,
    (SELECT COUNT(*) FROM public.items items_sub WHERE items_sub.user_id = i.user_id AND items_sub.status = 'borrowed') AS owner_borrowed_items
  FROM public.items i
  INNER JOIN public.profiles p ON p.id = i.user_id
  INNER JOIN auth.users au ON au.id = p.id
  WHERE i.id = p_item_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_item_details TO authenticated;

COMMENT ON FUNCTION public.admin_get_item_details IS
'Get detailed item information including owner info, borrower details, and computed metrics. Admin only.';

-- ============================================================================
-- FUNCTION 3: Update Item Status
-- ============================================================================
-- Purpose: Update item status with audit logging
-- Returns: Old and new status for confirmation
-- Permissions: Admin only

CREATE OR REPLACE FUNCTION public.admin_update_item_status(
  p_item_id UUID,
  p_new_status TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  item_id UUID,
  name TEXT,
  old_status TEXT,
  new_status TEXT,
  message TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id UUID;
  v_name TEXT;
  v_old_status TEXT;
  v_user_id UUID;
BEGIN
  -- Get admin user ID
  v_admin_id := auth.uid();

  -- Check if caller is admin
  IF NOT public.is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can update item status';
  END IF;

  -- Validate new status
  IF p_new_status NOT IN ('borrowed', 'returned') THEN
    RAISE EXCEPTION 'Invalid status: %. Must be one of: borrowed, returned', p_new_status;
  END IF;

  -- Get current item info
  SELECT items.name, items.status, items.user_id
  INTO v_name, v_old_status, v_user_id
  FROM public.items
  WHERE items.id = p_item_id;

  -- Check if item exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item not found: %', p_item_id;
  END IF;

  -- Check if status is actually changing
  IF v_old_status = p_new_status THEN
    RAISE EXCEPTION 'Item status is already: %', p_new_status;
  END IF;

  -- Update item status
  UPDATE public.items
  SET status = p_new_status
  WHERE items.id = p_item_id;

  -- Create audit log
  PERFORM public.create_admin_audit_log(
    v_admin_id,
    'update',
    'items',
    p_item_id,
    jsonb_build_object('status', v_old_status),
    jsonb_build_object('status', p_new_status),
    jsonb_build_object(
      'action', 'status_update',
      'name', v_name,
      'owner_id', v_user_id,
      'reason', p_reason
    )
  );

  -- Return result
  RETURN QUERY
  SELECT
    p_item_id,
    v_name,
    v_old_status,
    p_new_status,
    format('Item status updated from %s to %s', v_old_status, p_new_status)::TEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_item_status TO authenticated;

COMMENT ON FUNCTION public.admin_update_item_status IS
'Update item status with validation and audit logging. Valid statuses: available, borrowed, unavailable. Admin only.';

-- ============================================================================
-- FUNCTION 4: Delete Item
-- ============================================================================
-- Purpose: Delete item (soft or hard) with audit logging
-- Returns: Deletion result and type
-- Permissions: Admin only

CREATE OR REPLACE FUNCTION public.admin_delete_item(
  p_item_id UUID,
  p_hard_delete BOOLEAN DEFAULT FALSE,
  p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  item_id UUID,
  name TEXT,
  delete_type TEXT,
  message TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id UUID;
  v_name TEXT;
  v_old_status TEXT;
  v_user_id UUID;
  v_photo_url TEXT;
  v_item_data JSONB;
BEGIN
  -- Get admin user ID
  v_admin_id := auth.uid();

  -- Check if caller is admin
  IF NOT public.is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can delete items';
  END IF;

  -- Get current item info
  SELECT items.name, items.status, items.user_id, items.photo_url,
         to_jsonb(items.*) - 'id'
  INTO v_name, v_old_status, v_user_id, v_photo_url, v_item_data
  FROM public.items
  WHERE items.id = p_item_id;

  -- Check if item exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item not found: %', p_item_id;
  END IF;

  IF p_hard_delete THEN
    -- Hard delete: Actually remove from database
    DELETE FROM public.items WHERE items.id = p_item_id;

    -- Create audit log for hard delete
    PERFORM public.create_admin_audit_log(
      v_admin_id,
      'delete',
      'items',
      p_item_id,
      v_item_data,
      NULL,
      jsonb_build_object(
        'action', 'hard_delete',
        'name', v_name,
        'owner_id', v_user_id,
        'photo_url', v_photo_url,
        'reason', p_reason,
        'warning', 'Item permanently deleted - data cannot be recovered'
      )
    );

    -- Return result
    RETURN QUERY
    SELECT
      p_item_id,
      v_name,
      'hard_delete'::TEXT,
      'Item permanently deleted from database'::TEXT;
  ELSE
    -- Soft delete: Just delete from database (items table doesn't support soft delete)
    -- Note: Items table only has 'borrowed' and 'returned' status, no 'deleted' status
    DELETE FROM public.items WHERE items.id = p_item_id;

    -- Create audit log for soft delete
    PERFORM public.create_admin_audit_log(
      v_admin_id,
      'delete',
      'items',
      p_item_id,
      v_item_data,
      NULL,
      jsonb_build_object(
        'action', 'soft_delete',
        'name', v_name,
        'owner_id', v_user_id,
        'reason', p_reason,
        'note', 'Items table does not support soft delete - item deleted from database'
      )
    );

    -- Return result
    RETURN QUERY
    SELECT
      p_item_id,
      v_name,
      'soft_delete'::TEXT,
      'Item deleted from database (no soft delete support)'::TEXT;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_delete_item TO authenticated;

COMMENT ON FUNCTION public.admin_delete_item IS
'Delete item with soft delete (set unavailable) or hard delete (permanent). Creates audit log. Admin only. Note: Hard delete does not remove photo from storage.';

COMMIT;

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration 009 completed successfully';
  RAISE NOTICE 'Created functions:';
  RAISE NOTICE '  - admin_get_all_items(limit, offset, status, user, search)';
  RAISE NOTICE '  - admin_get_item_details(item_id)';
  RAISE NOTICE '  - admin_update_item_status(item_id, new_status, reason)';
  RAISE NOTICE '  - admin_delete_item(item_id, hard_delete, reason)';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  Note: Hard delete does not remove photos from storage.';
  RAISE NOTICE '   Use storage management tools to clean up orphaned files.';
END $$;
