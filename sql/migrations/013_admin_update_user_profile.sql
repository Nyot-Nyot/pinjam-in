-- Migration: Add admin_update_user_profile function
-- This allows admins to update user profiles bypassing RLS

CREATE OR REPLACE FUNCTION admin_update_user_profile(
  p_user_id UUID,
  p_full_name TEXT
)
RETURNS TABLE (
  user_id UUID,
  user_full_name TEXT,
  user_role TEXT,
  user_status TEXT,
  user_updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER -- Run with function owner's privileges, bypassing RLS
AS $$
DECLARE
  v_admin_role TEXT;
BEGIN
  -- Check if caller is admin
  SELECT p.role INTO v_admin_role
  FROM public.profiles p
  WHERE p.id = auth.uid();

  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can update user profiles'
      USING HINT = 'User must have admin role';
  END IF;

  -- Update or insert profile (UPSERT)
  INSERT INTO public.profiles (id, full_name, updated_at)
  VALUES (p_user_id, p_full_name, NOW())
  ON CONFLICT (id)
  DO UPDATE SET
    full_name = EXCLUDED.full_name,
    updated_at = NOW();

  -- Return updated profile
  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    p.role,
    p.status,
    p.updated_at
  FROM public.profiles p
  WHERE p.id = p_user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION admin_update_user_profile TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION admin_update_user_profile IS 'Allows admins to update user profile (full_name). Uses SECURITY DEFINER to bypass RLS.';
