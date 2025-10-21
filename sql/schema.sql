-- Supabase Schema: Borrowed Items Manager
-- Date: 2025-10-21
-- Feature: Borrowed Items Manager

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

-- Create RLS policies
-- Policy: Users can see their own items.
CREATE POLICY "Allow users to view their own items"
ON public.items
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own items.
CREATE POLICY "Allow users to insert their own items"
ON public.items
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own items.
CREATE POLICY "Allow users to update their own items"
ON public.items
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can delete their own items.
CREATE POLICY "Allow users to delete their own items"
ON public.items
FOR DELETE
USING (auth.uid() = user_id);

-- Create a storage bucket for item photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('item_photos', 'item_photos', false)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies if they exist
DROP POLICY IF EXISTS "Allow users to view their own photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to upload photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own photos" ON storage.objects;

-- RLS Policy: Allow users to view their own photos.
-- The photo path should include the user_id, e.g., "{user_id}/{item_id}.jpg"
CREATE POLICY "Allow users to view their own photos"
ON storage.objects
FOR SELECT
USING (bucket_id = 'item_photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- RLS Policy: Allow users to upload photos for their items.
CREATE POLICY "Allow users to upload photos"
ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'item_photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- RLS Policy: Allow users to delete their own photos.
CREATE POLICY "Allow users to delete their own photos"
ON storage.objects
FOR DELETE
USING (bucket_id = 'item_photos' AND auth.uid()::text = (storage.foldername(name))[1]);
