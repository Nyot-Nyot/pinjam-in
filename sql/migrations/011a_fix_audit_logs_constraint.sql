-- Migration: Fix audit_logs action_type constraint
-- Description: Update CHECK constraint to support both lowercase and new action types
-- Dependencies: Requires migration 002 (audit_logs table)
-- Author: Admin Implementation Team
-- Date: 2025-12-02
-- Reason: Migration 011 functions use uppercase and new action types

-- ============================================================================
-- DROP OLD CONSTRAINT AND ADD NEW ONE
-- ============================================================================

-- Drop the old constraint
ALTER TABLE public.audit_logs
DROP CONSTRAINT IF EXISTS audit_logs_action_type_check;

-- Add new constraint with expanded action types (case-insensitive)
ALTER TABLE public.audit_logs
ADD CONSTRAINT audit_logs_action_type_check
CHECK (action_type IN (
  -- Original lowercase (backwards compatible)
  'create', 'update', 'delete', 'view',
  -- New uppercase (used by admin functions)
  'CREATE', 'UPDATE', 'DELETE', 'VIEW',
  -- New action types
  'STATUS_CHANGE', 'ROLE_CHANGE', 'CUSTOM'
));

-- Verification
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration 011a completed successfully';
  RAISE NOTICE 'Updated audit_logs action_type constraint';
  RAISE NOTICE 'Allowed values:';
  RAISE NOTICE '  - Lowercase: create, update, delete, view';
  RAISE NOTICE '  - Uppercase: CREATE, UPDATE, DELETE, VIEW';
  RAISE NOTICE '  - New types: STATUS_CHANGE, ROLE_CHANGE, CUSTOM';
  RAISE NOTICE '';
END $$;
