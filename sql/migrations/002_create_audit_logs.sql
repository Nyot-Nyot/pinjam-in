-- Migration: Create audit logs table for tracking admin actions
-- Filename: sql/migrations/002_create_audit_logs.sql
-- Purpose: Create audit_logs table to track all administrative actions
-- for compliance and security monitoring

BEGIN;

-- ============================================================
-- CREATE AUDIT_LOGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL CHECK (action_type IN ('create', 'update', 'delete', 'view')),
  table_name TEXT NOT NULL,
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================================
-- Index on admin_user_id for filtering by admin
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin_user_id
  ON public.audit_logs(admin_user_id);

-- Index on action_type for filtering by action
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type
  ON public.audit_logs(action_type);

-- Index on table_name for filtering by affected table
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name
  ON public.audit_logs(table_name);

-- Index on created_at for time-based queries (most recent first)
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at
  ON public.audit_logs(created_at DESC);

-- Composite index for common query pattern (table + action + date)
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_action_date
  ON public.audit_logs(table_name, action_type, created_at DESC);

-- ============================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS POLICIES
-- ============================================================
-- Policy: Only admins can view audit logs
CREATE POLICY "Allow admins to view audit logs"
ON public.audit_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

-- Policy: Only admins can insert audit logs (through functions)
CREATE POLICY "Allow admins to insert audit logs"
ON public.audit_logs
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

-- Note: No UPDATE or DELETE policies - audit logs should be immutable
-- If you need to delete old logs, use a service role or database function

COMMIT;

-- ============================================================
-- VERIFICATION QUERIES (Run these to test)
-- ============================================================
-- Test: Verify table was created
-- SELECT table_name, column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'audit_logs'
-- ORDER BY ordinal_position;

-- Test: Verify indexes were created
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE tablename = 'audit_logs';

-- Test: Verify RLS is enabled
-- SELECT tablename, rowsecurity
-- FROM pg_tables
-- WHERE tablename = 'audit_logs';

-- Test: Insert sample audit log (as admin)
-- INSERT INTO public.audit_logs (admin_user_id, action_type, table_name, record_id, metadata)
-- VALUES (auth.uid(), 'create', 'items', gen_random_uuid(), '{"ip": "127.0.0.1"}'::jsonb);
