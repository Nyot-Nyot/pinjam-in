-- Migration: Add Admin Audit & Utility Functions
-- Description: Create functions for audit log management and storage utilities
-- Dependencies: Requires migrations 001-010 (audit_logs, profiles, items, storage tables)
-- Author: Admin Implementation Team
-- Date: 2025-12-02

-- ============================================================================
-- AUDIT & UTILITY FUNCTIONS FOR ADMIN
-- ============================================================================
-- These functions provide audit log management and utility functions for
-- admin operations. All functions require admin privileges (checked via is_admin).
--
-- Functions:
-- 1. admin_create_audit_log(...) - Create audit log entry
-- 2. admin_get_audit_logs(filters) - Get filtered audit logs with pagination
-- 3. admin_get_storage_stats() - Get storage usage statistics
--
-- IMPORTANT NOTES:
-- - All functions use SECURITY DEFINER for elevated privileges
-- - is_admin() check ensures only admins can execute
-- - audit_logs table must exist (migration 001)
-- - storage.objects is Supabase internal table for file metadata
-- ============================================================================

-- ============================================================================
-- FUNCTION 1: admin_create_audit_log
-- ============================================================================
-- Purpose: Create an audit log entry manually
-- Parameters:
--   - p_action_type: Type of action (e.g., 'UPDATE', 'DELETE', 'CREATE')
--   - p_table_name: Table being audited
--   - p_record_id: ID of the record affected
--   - p_old_values: JSONB of old values (NULL for CREATE)
--   - p_new_values: JSONB of new values (NULL for DELETE)
--   - p_metadata: Additional metadata (optional)
-- Returns: The created audit_log record
-- Usage: SELECT * FROM admin_create_audit_log('UPDATE', 'profiles', 'uuid', '{"role":"user"}', '{"role":"admin"}', '{"reason":"promotion"}');
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_create_audit_log(
  p_action_type TEXT,
  p_table_name TEXT,
  p_record_id UUID,
  p_old_values JSONB DEFAULT NULL,
  p_new_values JSONB DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  admin_user_id UUID,
  action_type TEXT,
  table_name TEXT,
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  metadata JSONB,
  created_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id UUID;
  v_audit_id UUID;
BEGIN
  -- Get admin user ID
  v_admin_id := auth.uid();

  -- Check if caller is admin
  IF NOT public.is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can create audit logs';
  END IF;

  -- Validate required parameters
  IF p_action_type IS NULL OR p_action_type = '' THEN
    RAISE EXCEPTION 'Invalid action_type: Cannot be NULL or empty';
  END IF;

  IF p_table_name IS NULL OR p_table_name = '' THEN
    RAISE EXCEPTION 'Invalid table_name: Cannot be NULL or empty';
  END IF;

  IF p_record_id IS NULL THEN
    RAISE EXCEPTION 'Invalid record_id: Cannot be NULL';
  END IF;

  -- Validate action_type is one of the expected values
  IF p_action_type NOT IN ('CREATE', 'UPDATE', 'DELETE', 'STATUS_CHANGE', 'ROLE_CHANGE', 'CUSTOM') THEN
    RAISE EXCEPTION 'Invalid action_type: %. Must be one of: CREATE, UPDATE, DELETE, STATUS_CHANGE, ROLE_CHANGE, CUSTOM', p_action_type;
  END IF;

  -- Insert audit log
  INSERT INTO public.audit_logs (
    admin_user_id,
    action_type,
    table_name,
    record_id,
    old_values,
    new_values,
    metadata
  ) VALUES (
    v_admin_id,
    p_action_type,
    p_table_name,
    p_record_id,
    p_old_values,
    p_new_values,
    p_metadata
  )
  RETURNING audit_logs.id INTO v_audit_id;

  -- Return the created audit log
  RETURN QUERY
  SELECT
    al.id,
    al.admin_user_id,
    al.action_type,
    al.table_name,
    al.record_id,
    al.old_values,
    al.new_values,
    al.metadata,
    al.created_at
  FROM public.audit_logs al
  WHERE al.id = v_audit_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_audit_log TO authenticated;

COMMENT ON FUNCTION public.admin_create_audit_log IS
'Create an audit log entry. Returns the created audit log record. Admin only.';

-- ============================================================================
-- FUNCTION 2: admin_get_audit_logs
-- ============================================================================
-- Purpose: Get filtered audit logs with pagination
-- Parameters: p_filters - JSONB with optional filters:
--   - user_id (UUID): Filter by admin user
--   - action_type (TEXT): Filter by action type
--   - table_name (TEXT): Filter by table
--   - date_from (DATE): Filter from date
--   - date_to (DATE): Filter to date
--   - limit (INT): Results per page (default 50, max 200)
--   - offset (INT): Pagination offset (default 0)
-- Returns: Audit logs with admin user info
-- Usage: SELECT * FROM admin_get_audit_logs('{"table_name":"profiles","limit":20}');
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_audit_logs(
  p_filters JSONB DEFAULT '{}'::JSONB
)
RETURNS TABLE (
  id UUID,
  admin_user_id UUID,
  admin_name TEXT,
  admin_email VARCHAR(255),
  action_type TEXT,
  table_name TEXT,
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  metadata JSONB,
  created_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id UUID;
  v_user_id UUID;
  v_action_type TEXT;
  v_table_name TEXT;
  v_date_from DATE;
  v_date_to DATE;
  v_limit INT;
  v_offset INT;
BEGIN
  -- Get admin user ID
  v_admin_id := auth.uid();

  -- Check if caller is admin
  IF NOT public.is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view audit logs';
  END IF;

  -- Extract filters from JSONB
  v_user_id := (p_filters->>'user_id')::UUID;
  v_action_type := p_filters->>'action_type';
  v_table_name := p_filters->>'table_name';
  v_date_from := (p_filters->>'date_from')::DATE;
  v_date_to := (p_filters->>'date_to')::DATE;
  v_limit := COALESCE((p_filters->>'limit')::INT, 50);
  v_offset := COALESCE((p_filters->>'offset')::INT, 0);

  -- Validate limit
  IF v_limit <= 0 OR v_limit > 200 THEN
    RAISE EXCEPTION 'Invalid limit: %. Must be between 1 and 200', v_limit;
  END IF;

  -- Validate offset
  IF v_offset < 0 THEN
    RAISE EXCEPTION 'Invalid offset: %. Must be >= 0', v_offset;
  END IF;

  -- Return filtered audit logs
  RETURN QUERY
  SELECT
    al.id,
    al.admin_user_id,
    p.full_name AS admin_name,
    au.email AS admin_email,
    al.action_type,
    al.table_name,
    al.record_id,
    al.old_values,
    al.new_values,
    al.metadata,
    al.created_at
  FROM public.audit_logs al
  INNER JOIN public.profiles p ON p.id = al.admin_user_id
  INNER JOIN auth.users au ON au.id = al.admin_user_id
  WHERE
    (v_user_id IS NULL OR al.admin_user_id = v_user_id)
    AND (v_action_type IS NULL OR al.action_type = v_action_type)
    AND (v_table_name IS NULL OR al.table_name = v_table_name)
    AND (v_date_from IS NULL OR al.created_at >= v_date_from)
    AND (v_date_to IS NULL OR al.created_at <= v_date_to + INTERVAL '1 day')
  ORDER BY al.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_audit_logs TO authenticated;

COMMENT ON FUNCTION public.admin_get_audit_logs IS
'Get filtered audit logs with pagination. Supports filters: user_id, action_type, table_name, date_from, date_to, limit, offset. Admin only.';

-- ============================================================================
-- FUNCTION 3: admin_get_storage_stats
-- ============================================================================
-- Purpose: Get storage usage statistics
-- Returns: Storage metrics including total files, total size, usage by user, orphaned files
-- Usage: SELECT * FROM admin_get_storage_stats();
-- Note: Queries storage.objects which requires SECURITY DEFINER
-- ============================================================================

-- Drop any older overload with no parameters to avoid ambiguity when adding
-- the new parameterized overload. This ensures CREATE OR REPLACE will not
-- just add another overload and cause callers to be ambiguous.
DROP FUNCTION IF EXISTS public.admin_get_storage_stats();

CREATE OR REPLACE FUNCTION public.admin_get_storage_stats(
  p_bucket_id TEXT DEFAULT 'item_photos'
)
RETURNS TABLE (
  total_files BIGINT,
  total_size_bytes BIGINT,
  total_size_mb NUMERIC,
  items_with_photos BIGINT,
  orphaned_files BIGINT,
  avg_file_size_kb NUMERIC,
  largest_file_size_mb NUMERIC,
  smallest_file_size_kb NUMERIC
)
SECURITY DEFINER
SET search_path = public, storage
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  -- Get admin user ID
  v_admin_id := auth.uid();

  -- Check if caller is admin
  IF NOT public.is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view storage statistics';
  END IF;

  -- Return storage statistics
  RETURN QUERY
  SELECT
    -- Total files in storage
    (SELECT COUNT(*)::BIGINT
  FROM storage.objects
  WHERE bucket_id = p_bucket_id)::BIGINT AS total_files,

  -- Total size in bytes (cast text to BIGINT before summing)
  (SELECT COALESCE(SUM(NULLIF(metadata->>'size', '')::BIGINT), 0)
  FROM storage.objects
  WHERE bucket_id = p_bucket_id)::BIGINT AS total_size_bytes,

    -- Total size in MB
  (SELECT COALESCE(ROUND((SUM(NULLIF(metadata->>'size', '')::BIGINT) / 1048576.0)::NUMERIC, 2), 0)
  FROM storage.objects
  WHERE bucket_id = p_bucket_id)::NUMERIC AS total_size_mb,

    -- Items with photos
    (SELECT COUNT(*)::BIGINT
     FROM public.items
     WHERE photo_url IS NOT NULL)::BIGINT AS items_with_photos,

    -- Orphaned files (files in storage but not in items table)
    (SELECT COUNT(*)::BIGINT
  FROM storage.objects so
  WHERE so.bucket_id = p_bucket_id
       AND NOT EXISTS (
         SELECT 1 FROM public.items i
         WHERE i.photo_url LIKE '%' || so.name || '%'
       ))::BIGINT AS orphaned_files,

    -- Average file size in KB
  (SELECT COALESCE(ROUND((AVG(NULLIF(metadata->>'size', '')::BIGINT) / 1024.0)::NUMERIC, 2), 0)
  FROM storage.objects
  WHERE bucket_id = p_bucket_id)::NUMERIC AS avg_file_size_kb,

    -- Largest file in MB
  (SELECT COALESCE(ROUND((MAX(NULLIF(metadata->>'size', '')::BIGINT) / 1048576.0)::NUMERIC, 2), 0)
  FROM storage.objects
  WHERE bucket_id = p_bucket_id)::NUMERIC AS largest_file_size_mb,

    -- Smallest file in KB
  (SELECT COALESCE(ROUND((MIN(NULLIF(metadata->>'size', '')::BIGINT) / 1024.0)::NUMERIC, 2), 0)
  FROM storage.objects
  WHERE bucket_id = p_bucket_id)::NUMERIC AS smallest_file_size_kb;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_storage_stats TO authenticated;

COMMENT ON FUNCTION public.admin_get_storage_stats IS
'Get storage usage statistics including total files, size, orphaned files, and file size metrics. Admin only.';

-- ==========================================================================
-- FUNCTION 4: admin_get_storage_by_user
-- Purpose: Return top users by storage usage for given bucket
-- Returns: user_id, user_email, total_size_bytes, file_count
-- Usage: SELECT * FROM admin_get_storage_by_user('item_photos', 10);
-- ===========================================================================

-- Ensure old overloads do not cause type mismatches
DROP FUNCTION IF EXISTS public.admin_get_storage_by_user(TEXT, INT);
CREATE OR REPLACE FUNCTION public.admin_get_storage_by_user(
  p_bucket_id TEXT DEFAULT 'item_photos',
  p_limit INT DEFAULT 10
)
RETURNS TABLE (
  user_id UUID,
  user_email TEXT,
  total_size_bytes BIGINT,
  file_count BIGINT
)
SECURITY DEFINER
SET search_path = public, storage
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT public.is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view storage by user';
  END IF;

  RETURN QUERY
  SELECT
    i.user_id,
    au.email::text AS user_email,
    COALESCE(SUM(NULLIF(so.metadata->>'size','')::BIGINT), 0)::BIGINT AS total_size_bytes,
    COUNT(so.*)::BIGINT AS file_count
  FROM storage.objects so
  JOIN public.items i ON i.photo_url LIKE '%' || so.name || '%'
  LEFT JOIN auth.users au ON au.id = i.user_id
  WHERE so.bucket_id = p_bucket_id
  GROUP BY i.user_id, au.email
  ORDER BY total_size_bytes DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_storage_by_user TO authenticated;

COMMENT ON FUNCTION public.admin_get_storage_by_user IS
  'Get storage usage by user (top N). Use p_bucket_id and p_limit to filter.';

-- ============================================================================
-- FUNCTION 5: admin_get_storage_file_type_distribution
-- Purpose: Return file type distribution by extension in the bucket
-- Returns: extension, file_count, total_size_bytes
-- Usage: SELECT * FROM admin_get_storage_file_type_distribution('item_photos');
-- ============================================================================

DROP FUNCTION IF EXISTS public.admin_get_storage_file_type_distribution(TEXT);
CREATE OR REPLACE FUNCTION public.admin_get_storage_file_type_distribution(
  p_bucket_id TEXT DEFAULT 'item_photos'
)
RETURNS TABLE (
  extension TEXT,
  file_count BIGINT,
  total_size_bytes BIGINT
)
SECURITY DEFINER
SET search_path = public, storage
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT public.is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can view file type distribution';
  END IF;

  RETURN QUERY
  SELECT
    LOWER(REGEXP_REPLACE(split_part(so.name, '.', array_length(string_to_array(so.name, '.'),1)) , '[^a-zA-Z0-9]+', '', 'g'))::text AS extension,
    COUNT(*)::BIGINT AS file_count,
    COALESCE(SUM(NULLIF(so.metadata->>'size','')::BIGINT), 0)::BIGINT AS total_size_bytes
  FROM storage.objects so
  WHERE so.bucket_id = p_bucket_id
  GROUP BY extension
  ORDER BY file_count DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_storage_file_type_distribution TO authenticated;

-- ============================================================================
-- FUNCTION 6: admin_list_storage_files
-- Purpose: List files in a storage bucket (with pagination/search)
-- Returns: id, name, owner, bucket_id, size_bytes, created_at, updated_at, metadata
-- Usage: SELECT * FROM admin_list_storage_files('item_photos', 50, 0, 'user_');
-- ============================================================================

DROP FUNCTION IF EXISTS public.admin_list_storage_files(TEXT, INT, INT, TEXT);
CREATE OR REPLACE FUNCTION public.admin_list_storage_files(
  p_bucket_id TEXT DEFAULT 'item_photos',
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
  id TEXT,
  name TEXT,
  owner UUID,
  bucket_id TEXT,
  size_bytes BIGINT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  metadata JSONB
)
SECURITY DEFINER
SET search_path = public, storage
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT public.is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Permission denied: Only admins can list storage files';
  END IF;

  RETURN QUERY
  SELECT
    so.id::text,
    so.name::text AS name,
    so.owner,
    so.bucket_id::text AS bucket_id,
    COALESCE(NULLIF(so.metadata->>'size','')::BIGINT, 0)::BIGINT AS size_bytes,
    so.created_at,
    so.updated_at,
    so.metadata
  FROM storage.objects so
  WHERE so.bucket_id = p_bucket_id
    AND (p_search IS NULL OR so.name ILIKE '%' || p_search || '%')
  ORDER BY so.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_storage_files TO authenticated;

COMMENT ON FUNCTION public.admin_list_storage_files IS
  'List storage files with pagination and optional name search. Admin only.';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration 011 completed successfully';
  RAISE NOTICE 'Created admin audit & utility functions:';
  RAISE NOTICE '  - admin_create_audit_log(...) → create audit log entry';
  RAISE NOTICE '  - admin_get_audit_logs(filters) → get filtered audit logs';
  RAISE NOTICE '  - admin_get_storage_stats() → storage usage statistics';
  RAISE NOTICE '';
  RAISE NOTICE '📊 All functions are admin-only (SECURITY DEFINER)';
  RAISE NOTICE '🔍 audit_logs table required (migration 001)';
  RAISE NOTICE '💾 storage.objects access requires SECURITY DEFINER';
END $$;
