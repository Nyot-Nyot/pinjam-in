-- Supabase Schema: Borrowed Items Manager# Supabase Schema: Borrowed Items Manager

-- Date: 2025-10-21

-- Feature: Borrowed Items Manager**Date**: 2025-10-21

**Feature**: Borrowed Items Manager

-- Create the 'items' table

CREATE TABLE IF NOT EXISTS public.items (This file defines the SQL schema for the tables required in the Supabase PostgreSQL database.

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,## `items` Table

  name TEXT NOT NULL CHECK (char_length(name) >= 3),

  photo_url TEXT,This table will store all the borrowed item records.

  borrower_name TEXT NOT NULL CHECK (char_length(borrower_name) >= 3),

  borrower_contact_id TEXT,```sql

  borrow_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),-- Create the 'items' table

  return_date DATE,CREATE TABLE public.items (

  status TEXT NOT NULL DEFAULT 'borrowed' CHECK (status IN ('borrowed', 'returned')),  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  notes TEXT,  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()  name TEXT NOT NULL CHECK (char_length(name) >= 3),

);  photo_url TEXT,

  borrower_name TEXT NOT NULL CHECK (char_length(borrower_name) >= 3),

-- Enable Row Level Security (RLS)  borrower_contact_id TEXT,

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;  borrow_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  return_date DATE,

-- Drop existing policies if any  status TEXT NOT NULL DEFAULT 'borrowed' CHECK (status IN ('borrowed', 'returned')),

DROP POLICY IF EXISTS "Allow users to view their own items" ON public.items;  notes TEXT,

DROP POLICY IF EXISTS "Allow users to insert their own items" ON public.items;  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

DROP POLICY IF EXISTS "Allow users to update their own items" ON public.items;);

DROP POLICY IF EXISTS "Allow users to delete their own items" ON public.items;

-- Enable Row Level Security (RLS)

-- Create RLS policiesALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own items.

CREATE POLICY "Allow users to view their own items"-- Create RLS policies

ON public.items-- Policy: Users can see their own items.

FOR SELECTCREATE POLICY "Allow users to view their own items"

USING (auth.uid() = user_id);ON public.items

FOR SELECT

-- Policy: Users can insert their own items.USING (auth.uid() = user_id);

CREATE POLICY "Allow users to insert their own items"

ON public.items-- Policy: Users can insert their own items.

FOR INSERTCREATE POLICY "Allow users to insert their own items"

WITH CHECK (auth.uid() = user_id);ON public.items

FOR INSERT

-- Policy: Users can update their own items.WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to update their own items"

ON public.items-- Policy: Users can update their own items.

FOR UPDATECREATE POLICY "Allow users to update their own items"

USING (auth.uid() = user_id);ON public.items

FOR UPDATE

-- Policy: Users can delete their own items.USING (auth.uid() = user_id);

CREATE POLICY "Allow users to delete their own items"

ON public.items-- Policy: Users can delete their own items.

FOR DELETECREATE POLICY "Allow users to delete their own items"

USING (auth.uid() = user_id);ON public.items

FOR DELETE

-- Create a storage bucket for item photosUSING (auth.uid() = user_id);

INSERT INTO storage.buckets (id, name, public)```

VALUES ('item_photos', 'item_photos', false)

ON CONFLICT (id) DO NOTHING;## `storage.objects` (for Photos)



-- Drop existing storage policies if anyA Supabase Storage bucket will be created to store the photos of the items.

DROP POLICY IF EXISTS "Allow users to view their own photos" ON storage.objects;

DROP POLICY IF EXISTS "Allow users to upload photos" ON storage.objects;-   **Bucket Name**: `item_photos`

DROP POLICY IF EXISTS "Allow users to delete their own photos" ON storage.objects;-   **Access Policy**:

    -   Users should only be able to upload photos for items they own.

-- RLS Policy: Allow users to view their own photos.    -   Users should only be able to read photos for items they own.

-- The photo path should include the user_id, e.g., "{user_id}/{item_id}.jpg"

CREATE POLICY "Allow users to view their own photos"```sql

ON storage.objects-- Create a storage bucket for item photos

FOR SELECTINSERT INTO storage.buckets (id, name, public)

USING (bucket_id = 'item_photos' AND auth.uid()::text = (storage.foldername(name))[1]);VALUES ('item_photos', 'item_photos', false);



-- RLS Policy: Allow users to upload photos for their items.-- RLS Policy: Allow users to view their own photos.

CREATE POLICY "Allow users to upload photos"-- The photo path should include the user_id, e.g., "{user_id}/{item_id}.jpg"

ON storage.objectsCREATE POLICY "Allow users to view their own photos"

FOR INSERTON storage.objects

WITH CHECK (bucket_id = 'item_photos' AND auth.uid()::text = (storage.foldername(name))[1]);FOR SELECT

USING (bucket_id = 'item_photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- RLS Policy: Allow users to delete their own photos.

CREATE POLICY "Allow users to delete their own photos"-- RLS Policy: Allow users to upload photos for their items.

ON storage.objectsCREATE POLICY "Allow users to upload photos"

FOR DELETEON storage.objects

USING (bucket_id = 'item_photos' AND auth.uid()::text = (storage.foldername(name))[1]);FOR INSERT

WITH CHECK (bucket_id = 'item_photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- RLS Policy: Allow users to delete their own photos.
CREATE POLICY "Allow users to delete their own photos"
ON storage.objects
FOR DELETE
USING (bucket_id = 'item_photos' AND auth.uid()::text = (storage.foldername(name))[1]);
```
