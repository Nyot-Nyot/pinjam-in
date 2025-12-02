-- Debug Script: Check photo URLs in items table
-- Run this in Supabase SQL Editor to diagnose photo URL issues

-- 1. Check sample of items with their photo URLs
SELECT
  id,
  name,
  photo_url,
  CASE
    WHEN photo_url IS NULL THEN 'NULL'
    WHEN photo_url = '' THEN 'EMPTY STRING'
    WHEN photo_url LIKE 'http%' THEN 'FULL URL'
    WHEN photo_url LIKE '%/%' THEN 'PATH'
    ELSE 'OTHER'
  END as url_type,
  created_at
FROM items
WHERE status = 'borrowed'
ORDER BY created_at DESC
LIMIT 10;

-- 2. Count items by photo URL status
SELECT
  CASE
    WHEN photo_url IS NULL THEN 'NULL'
    WHEN photo_url = '' THEN 'EMPTY'
    WHEN photo_url LIKE 'http%' THEN 'FULL_URL'
    ELSE 'PATH_ONLY'
  END as url_status,
  COUNT(*) as count
FROM items
GROUP BY url_status;

-- 3. Check storage.objects for actual files
SELECT
  name,
  bucket_id,
  owner,
  created_at,
  metadata->>'size' as file_size
FROM storage.objects
WHERE bucket_id = 'items'
ORDER BY created_at DESC
LIMIT 10;

-- 4. Cross-check: items with photo_url but no matching storage file
SELECT
  i.id,
  i.name,
  i.photo_url,
  i.user_id
FROM items i
WHERE i.photo_url IS NOT NULL
  AND i.photo_url != ''
  AND NOT EXISTS (
    SELECT 1
    FROM storage.objects o
    WHERE o.bucket_id = 'items'
    AND o.name = i.photo_url
  )
LIMIT 10;

-- 5. Cross-check: storage files with no matching items
SELECT
  o.name,
  o.bucket_id,
  o.created_at
FROM storage.objects o
WHERE o.bucket_id = 'items'
  AND NOT EXISTS (
    SELECT 1
    FROM items i
    WHERE i.photo_url = o.name
    OR i.photo_url LIKE '%' || o.name
  )
LIMIT 10;
