-- Grant Finance role write access to centres and groups tables.
-- Finance needs to create centres and groups during Excel imports.
-- Safe to re-run (idempotent: DROP IF EXISTS + CREATE POLICY).

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'centers') THEN
    DROP POLICY IF EXISTS "Admins can manage centers" ON public.centers;
    CREATE POLICY "Admins can manage centers" ON public.centers FOR ALL
      USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'groups') THEN
    DROP POLICY IF EXISTS "Admins can manage groups" ON public.groups;
    CREATE POLICY "Admins can manage groups" ON public.groups FOR ALL
      USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));
  END IF;
END $$;
