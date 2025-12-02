-- Migration: Add profiles table and update RLS to allow admin role
-- Filename: sql/migrations/001_add_profiles_and_admin_rls.sql
-- Purpose: Create a simple `profiles` table to hold user role metadata
-- and update Row Level Security (RLS) policies so users with role='admin'
-- can view/modify/delete all items while regular users keep their own-only access.

BEGIN;

-- 1) Create profiles table to store role metadata for auth.users
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2) Seed profiles for existing auth.users (mark all existing users as 'user')
INSERT INTO public.profiles (id, role)
SELECT id, 'user' FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 3) Update RLS policies on public.items to allow admin access
--    Keep per-user policies but expand them to include users whose profile.role = 'admin'

-- Remove existing policies so we can re-create them safely
DROP POLICY IF EXISTS "Allow users to view their own items" ON public.items;
DROP POLICY IF EXISTS "Allow users to insert their own items" ON public.items;
DROP POLICY IF EXISTS "Allow users to update their own items" ON public.items;
DROP POLICY IF EXISTS "Allow users to delete their own items" ON public.items;

-- SELECT: users can select their own items OR admins can select all
CREATE POLICY "Allow users to view own items or admins" ON public.items
  FOR SELECT USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- INSERT: allow insert when auth.uid() == user_id OR admin (admins inserting items
-- for other users may be allowed depending on your policy; here we allow admin insert)
CREATE POLICY "Allow users to insert own items or admins" ON public.items
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- UPDATE: allow update if owner OR admin
CREATE POLICY "Allow users to update own items or admins" ON public.items
  FOR UPDATE USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  ) WITH CHECK (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- DELETE: allow delete if owner OR admin
CREATE POLICY "Allow users to delete own items or admins" ON public.items
  FOR DELETE USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- 4) Update storage policies for bucket 'item_photos' to allow admin
-- Note: storage policies live in `storage.objects`. The existing project uses
-- policies that check auth.uid()::text = (storage.foldername(name))[1]
-- We'll add admin-aware policies for SELECT/INSERT/DELETE.

-- Drop any previous policies we will replace
DROP POLICY IF EXISTS "Allow users to view their own photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to upload photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own photos" ON storage.objects;

-- SELECT: allow if bucket is 'item_photos' and user is owner (foldername) or admin
CREATE POLICY "Allow users to view their own photos or admins" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'item_photos' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
      )
    )
  );

-- INSERT: allow upload if owner folder matches or admin
CREATE POLICY "Allow users to upload photos or admins" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'item_photos' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
      )
    )
  );

-- DELETE: allow delete if owner folder matches or admin
CREATE POLICY "Allow users to delete their own photos or admins" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'item_photos' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
      )
    )
  );

-- COMMIT;

-- Notes:
-- * Run this migration from Supabase SQL editor (it runs with service role) or via psql
--   connected to the project's database using a role with CREATE/ALTER privileges.
-- * After applying, create at least one admin manually by setting `role='admin'` in
--   `public.profiles` for the desired user id.
