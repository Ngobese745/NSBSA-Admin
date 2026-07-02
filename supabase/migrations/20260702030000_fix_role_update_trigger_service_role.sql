-- Fix the prevent_admin_critical_profile_edits trigger to allow
-- service-role (auth.uid() IS NULL) updates through.
-- The original trigger rejected role/status changes when the caller
-- was not a Super Admin, but auth.uid() returns NULL for the
-- service-role key, which is never equal to 'Super Admin'.

CREATE OR REPLACE FUNCTION public.prevent_admin_critical_profile_edits()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_role TEXT;
BEGIN
  SELECT role INTO current_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF current_role IS DISTINCT FROM 'Super Admin' AND auth.uid() IS NOT NULL THEN
    IF NEW.role IS DISTINCT FROM OLD.role OR NEW.status IS DISTINCT FROM OLD.status THEN
      RAISE EXCEPTION 'Only Super Admins can change user roles or status.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
