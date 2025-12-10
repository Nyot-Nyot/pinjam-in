-- Migration 013: Allow admins to delete storage objects in item_photos bucket

BEGIN;

-- Drop existing delete policy if present, then recreate with admin fallback
DROP POLICY IF EXISTS "Users can delete their own photos" ON storage.objects;

CREATE POLICY "Users can delete their own photos or admins" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'item_photos' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR public.is_admin(auth.uid())
    )
  );

COMMIT;

DO $$ BEGIN
  RAISE NOTICE '✅ Migration 013 created: Allow admins to delete storage objects in item_photos bucket';
END $$;
