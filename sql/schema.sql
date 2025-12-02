-- Supabase Schema: Borrowed Items Manager
-- Date: 2025-12-02 (Updated for admin role support)
-- Feature: Borrowed Items Manager with Admin Role

-- ============================================================
-- 1. PROFILES TABLE
-- ============================================================
-- Store user role metadata for auth.users
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','suspended')),
  last_login TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own profile
CREATE POLICY "Allow users to view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- RLS Policy: Users can update their own profile
CREATE POLICY "Allow users to update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- RLS Policy: Admins can view all profiles
CREATE POLICY "Allow admins to view all profiles" ON public.profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- RLS Policy: Admins can update all profiles
CREATE POLICY "Allow admins to update all profiles" ON public.profiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- ============================================================
-- 2. AUDIT_LOGS TABLE
-- ============================================================
-- Track all administrative actions for compliance
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

-- Enable RLS on audit_logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin_user_id ON public.audit_logs(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type ON public.audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name ON public.audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_action_date ON public.audit_logs(table_name, action_type, created_at DESC);

-- RLS Policy: Only admins can view audit logs
CREATE POLICY "Allow admins to view audit logs" ON public.audit_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- RLS Policy: Only admins can insert audit logs
CREATE POLICY "Allow admins to insert audit logs" ON public.audit_logs
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- ============================================================
-- 3. ITEMS TABLE
-- ============================================================
-- ============================================================
-- 3. ITEMS TABLE
-- ============================================================
-- Create the 'items' table
CREATE TABLE IF NOT EXISTS public.items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL CHECK (char_length(name) >= 3),
  photo_url TEXT,
  borrower_name TEXT NOT NULL CHECK (char_length(borrower_name) >= 3),
  borrower_contact_id TEXT,
  borrow_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  due_date DATE,
  return_date DATE,
  status TEXT NOT NULL DEFAULT 'borrowed' CHECK (status IN ('borrowed', 'returned')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for re-running the script)
DROP POLICY IF EXISTS "Allow users to view their own items" ON public.items;
DROP POLICY IF EXISTS "Allow users to insert their own items" ON public.items;
DROP POLICY IF EXISTS "Allow users to update their own items" ON public.items;
DROP POLICY IF EXISTS "Allow users to delete their own items" ON public.items;

-- Create RLS policies with admin support
-- Policy: Users can see their own items OR admins can see all
CREATE POLICY "Allow users to view own items or admins"
ON public.items
FOR SELECT
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

-- Policy: Users can insert their own items OR admins can insert
CREATE POLICY "Allow users to insert own items or admins"
ON public.items
FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

-- Policy: Users can update their own items OR admins can update all
CREATE POLICY "Allow users to update own items or admins"
ON public.items
FOR UPDATE
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  )
)
WITH CHECK (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

-- Policy: Users can delete their own items OR admins can delete all
CREATE POLICY "Allow users to delete own items or admins"
ON public.items
FOR DELETE
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

-- ============================================================
-- 4. STORAGE BUCKET & POLICIES
-- ============================================================

-- ============================================================
-- 3. STORAGE BUCKET & POLICIES
-- ============================================================
-- Create a storage bucket for item photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('item_photos', 'item_photos', false)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies if they exist
DROP POLICY IF EXISTS "Allow users to view their own photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to upload photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own photos" ON storage.objects;

-- RLS Policy: Allow users to view their own photos OR admins view all
-- The photo path should include the user_id, e.g., "{user_id}/{item_id}.jpg"
CREATE POLICY "Allow users to view their own photos or admins"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'item_photos' AND (
    auth.uid()::text = (storage.foldername(name))[1]
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  )
);

-- RLS Policy: Allow users to upload photos for their items OR admins upload
CREATE POLICY "Allow users to upload photos or admins"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'item_photos' AND (
    auth.uid()::text = (storage.foldername(name))[1]
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  )
);

-- RLS Policy: Allow users to delete their own photos OR admins delete all
CREATE POLICY "Allow users to delete their own photos or admins"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'item_photos' AND (
    auth.uid()::text = (storage.foldername(name))[1]
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  )
);
