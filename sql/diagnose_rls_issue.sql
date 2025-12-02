-- Diagnose RLS Issue
-- Purpose: Check current state of RLS policies to find the recursion source

-- ============================================================================
-- 1. CHECK ALL POLICIES ON PROFILES TABLE
-- ============================================================================
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'profiles';

-- ============================================================================
-- 2. CHECK RLS STATUS ON PROFILES
-- ============================================================================
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'profiles';

-- ============================================================================
-- 3. CHECK ALL POLICIES THAT REFERENCE PROFILES TABLE
-- ============================================================================
-- This will show any policy that queries the profiles table
SELECT
  schemaname,
  tablename,
  policyname,
  qual as using_clause
FROM pg_policies
WHERE qual LIKE '%profiles%'
  OR with_check LIKE '%profiles%';

-- ============================================================================
-- 4. CHECK is_admin() FUNCTION
-- ============================================================================
SELECT
  routine_name,
  routine_type,
  security_type,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'is_admin';
