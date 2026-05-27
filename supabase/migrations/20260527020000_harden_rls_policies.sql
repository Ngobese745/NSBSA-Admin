-- ──────────────────────────────────────────────────────────────────────────────
-- Harden RLS Policies for all business tables
-- ──────────────────────────────────────────────────────────────────────────────
-- Replaces dev-mode "Enable * for all users" policies with role-based
-- policies using public.has_role() and auth.role() checks.
--
-- Depends on: 20260527010000_data_api_grants_and_rls_hardening.sql
--   (which created the has_role() helper function)
--
-- Safe to re-run (idempotent: DROP IF EXISTS + CREATE OR REPLACE).
-- ──────────────────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 1: Drop dev-mode "Enable * for all users" policies across all tables
-- ══════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN (SELECT table_name FROM information_schema.tables
              WHERE table_schema = 'public')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Enable read access for all users" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Enable insert for all users" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Enable update for all users" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Enable delete for all users" ON public.%I', t);
    END LOOP;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 2: Role-based policies per table
-- ─═════════════════════════════════════════════════════════════════════════════
-- Each block guards with IF EXISTS so missing tables don't block the migration.

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'groups') THEN
    DROP POLICY IF EXISTS "Staff can view groups" ON public.groups;
    CREATE POLICY "Staff can view groups" ON public.groups FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Admins can manage groups" ON public.groups;
    CREATE POLICY "Admins can manage groups" ON public.groups FOR ALL
      USING (public.has_role(ARRAY['Super Admin', 'Admin']));
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vendors') THEN
    DROP POLICY IF EXISTS "Staff can view vendors" ON public.vendors;
    CREATE POLICY "Staff can view vendors" ON public.vendors FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Admins and Finance can manage vendors" ON public.vendors;
    CREATE POLICY "Admins and Finance can manage vendors" ON public.vendors FOR ALL
      USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'loans') THEN
    DROP POLICY IF EXISTS "Staff can view loans" ON public.loans;
    CREATE POLICY "Staff can view loans" ON public.loans FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Finance and Admin can manage loans" ON public.loans;
    CREATE POLICY "Finance and Admin can manage loans" ON public.loans FOR ALL
      USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'payments') THEN
    DROP POLICY IF EXISTS "Staff can view payments" ON public.payments;
    CREATE POLICY "Staff can view payments" ON public.payments FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Finance and Admin can manage payments" ON public.payments;
    CREATE POLICY "Finance and Admin can manage payments" ON public.payments FOR ALL
      USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'group_payments') THEN
    DROP POLICY IF EXISTS "Staff can view group payments" ON public.group_payments;
    CREATE POLICY "Staff can view group payments" ON public.group_payments FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Finance and Admin can manage group payments" ON public.group_payments;
    CREATE POLICY "Finance and Admin can manage group payments" ON public.group_payments FOR ALL
      USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'announcements') THEN
    DROP POLICY IF EXISTS "Staff can view announcements" ON public.announcements;
    CREATE POLICY "Staff can view announcements" ON public.announcements FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Marketing and Admin can manage announcements" ON public.announcements;
    CREATE POLICY "Marketing and Admin can manage announcements" ON public.announcements FOR ALL
      USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Marketing']));
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'savings_history') THEN
    DROP POLICY IF EXISTS "Staff can view savings history" ON public.savings_history;
    CREATE POLICY "Staff can view savings history" ON public.savings_history FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Staff can insert savings history" ON public.savings_history;
    CREATE POLICY "Staff can insert savings history" ON public.savings_history FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'account_audit_log') THEN
    DROP POLICY IF EXISTS "Only Super Admins can view audit logs" ON public.account_audit_log;
    CREATE POLICY "Only Super Admins can view audit logs" ON public.account_audit_log FOR SELECT
      USING (public.has_role(ARRAY['Super Admin']));
    DROP POLICY IF EXISTS "System can insert audit logs" ON public.account_audit_log;
    CREATE POLICY "System can insert audit logs" ON public.account_audit_log FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'password_reset_requests') THEN
    DROP POLICY IF EXISTS "Authenticated users can view reset requests" ON public.password_reset_requests;
    CREATE POLICY "Authenticated users can view reset requests" ON public.password_reset_requests FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Super Admins can manage reset requests" ON public.password_reset_requests;
    CREATE POLICY "Super Admins can manage reset requests" ON public.password_reset_requests FOR ALL
      USING (public.has_role(ARRAY['Super Admin']));
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
    DROP POLICY IF EXISTS "Profiles are viewable by authenticated staff" ON public.profiles;
    CREATE POLICY "Profiles are viewable by authenticated staff" ON public.profiles FOR SELECT
      USING (auth.role() = 'authenticated');
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'communication_logs') THEN
    DROP POLICY IF EXISTS "Staff can view communication logs" ON public.communication_logs;
    CREATE POLICY "Staff can view communication logs" ON public.communication_logs FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "System can insert communication logs" ON public.communication_logs;
    CREATE POLICY "System can insert communication logs" ON public.communication_logs FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'documents') THEN
    DROP POLICY IF EXISTS "Staff can view documents" ON public.documents;
    CREATE POLICY "Staff can view documents" ON public.documents FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Staff can insert documents" ON public.documents;
    CREATE POLICY "Staff can insert documents" ON public.documents FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Staff can delete documents" ON public.documents;
    CREATE POLICY "Staff can delete documents" ON public.documents FOR DELETE
      USING (auth.role() = 'authenticated');
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'system_audit_log') THEN
    DROP POLICY IF EXISTS "Super Admins can view system audit logs" ON public.system_audit_log;
    CREATE POLICY "Super Admins can view system audit logs" ON public.system_audit_log FOR SELECT
      USING (public.has_role(ARRAY['Super Admin']));
    DROP POLICY IF EXISTS "System can insert system audit logs" ON public.system_audit_log;
    CREATE POLICY "System can insert system audit logs" ON public.system_audit_log FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'centers') THEN
    DROP POLICY IF EXISTS "Staff can view centers" ON public.centers;
    CREATE POLICY "Staff can view centers" ON public.centers FOR SELECT
      USING (auth.role() = 'authenticated');
    DROP POLICY IF EXISTS "Admins can manage centers" ON public.centers;
    CREATE POLICY "Admins can manage centers" ON public.centers FOR ALL
      USING (public.has_role(ARRAY['Super Admin', 'Admin']));
  END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 3: Enable RLS on all tables (idempotent)
-- ══════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN (SELECT table_name FROM information_schema.tables
              WHERE table_schema = 'public'
              AND table_name NOT IN ('schema_migrations'))
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    END LOOP;
END $$;
