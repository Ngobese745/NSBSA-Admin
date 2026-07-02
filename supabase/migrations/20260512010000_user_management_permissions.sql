-- User Management permissions: profile status, department, and Admin/Super Admin guardrails.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS department TEXT;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'Active';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'valid_profile_status'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT valid_profile_status CHECK (status IN ('Active', 'Blocked'));
  END IF;
END $$;

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

DROP TRIGGER IF EXISTS trg_prevent_admin_critical_profile_edits ON public.profiles;
CREATE TRIGGER trg_prevent_admin_critical_profile_edits
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.prevent_admin_critical_profile_edits();

DROP POLICY IF EXISTS "Admins can update non-critical profile fields" ON public.profiles;
CREATE POLICY "Admins can update non-critical profile fields" ON public.profiles
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('Super Admin', 'Admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('Super Admin', 'Admin')
  )
);
