-- ──────────────────────────────────────────────────────────────────────────────
-- Data API Grants, RLS Hardening & Security Fixes
-- ──────────────────────────────────────────────────────────────────────────────
-- Required by Supabase's upcoming change (May 30, 2026 for new projects,
-- Oct 30, 2026 for existing): public schema tables need explicit GRANTs
-- to be accessible via PostgREST / Data API.
--
-- Also fixes:
--   1. Marketing tables use has_role() instead of auth.jwt() ->> 'role'
--   2. api_keys uses has_role() instead of auth.jwt() ->> 'role'
--   3. Hardens comments, leadership, notifications, account_setup_tokens
--   4. Adds RLS + policies for email_outbox
-- ──────────────────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 1: Data API Grants (required after Supabase default change)
-- ══════════════════════════════════════════════════════════════════════════════
GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated;

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 2: has_role() helper function (idempotent)
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.has_role(required_roles text[])
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = ANY(required_roles)
    AND status = 'Active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 3: Fix marketing tables — replace auth.jwt() role checks with has_role()
-- ══════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Allow marketing access to templates" ON public.marketing_templates;
DROP POLICY IF EXISTS "Allow marketing access to campaigns" ON public.marketing_campaigns;
DROP POLICY IF EXISTS "Allow marketing access to leads" ON public.marketing_leads;
DROP POLICY IF EXISTS "Allow marketing access to logs" ON public.marketing_logs;
DROP POLICY IF EXISTS "Allow marketing access to opt_outs" ON public.marketing_opt_outs;

CREATE POLICY "Marketing and Admins can manage templates"
  ON public.marketing_templates FOR ALL
  USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Marketing']));

CREATE POLICY "Marketing and Admins can manage campaigns"
  ON public.marketing_campaigns FOR ALL
  USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Marketing']));

CREATE POLICY "Marketing and Admins can manage leads"
  ON public.marketing_leads FOR ALL
  USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Marketing']));

CREATE POLICY "Marketing and Admins can manage logs"
  ON public.marketing_logs FOR ALL
  USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Marketing']));

CREATE POLICY "Marketing and Admins can manage opt_outs"
  ON public.marketing_opt_outs FOR ALL
  USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Marketing']));

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 4: Fix api_keys — replace auth.jwt() role check with has_role()
-- ══════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Super Admin and Developers can manage API keys"
  ON public.api_keys;

CREATE POLICY "Super Admin and Developers can manage API keys"
  ON public.api_keys FOR ALL
  TO authenticated
  USING (
    public.has_role(ARRAY['Super Admin'])
    OR auth.jwt() ->> 'email' = 'colane@mwelasefin.co.za'
  )
  WITH CHECK (
    public.has_role(ARRAY['Super Admin'])
    OR auth.jwt() ->> 'email' = 'colane@mwelasefin.co.za'
  );

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 5: Harden comments RLS
-- ══════════════════════════════════════════════════════════════════════════════
-- Drop any leftover dev policies
DROP POLICY IF EXISTS "Enable read access for all users" ON public.comments;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.comments;
DROP POLICY IF EXISTS "Enable update for all users" ON public.comments;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.comments;

CREATE POLICY "Staff can view comments"
  ON public.comments FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Staff can insert comments"
  ON public.comments FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Staff can update comments"
  ON public.comments FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Staff can delete comments"
  ON public.comments FOR DELETE
  USING (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 6: Harden leadership RLS
-- ══════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Public leadership is viewable by everyone"
  ON public.leadership;
DROP POLICY IF EXISTS "Admins can manage leadership"
  ON public.leadership;

CREATE POLICY "Staff can view leadership"
  ON public.leadership FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage leadership"
  ON public.leadership FOR ALL
  USING (public.has_role(ARRAY['Super Admin', 'Admin']));

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 7: Harden notifications RLS — use has_role() for role checks
-- ══════════════════════════════════════════════════════════════════════════════
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public'
             AND table_name = 'notifications') THEN

    DROP POLICY IF EXISTS "Users can view their own notifications"
      ON public.notifications;
    DROP POLICY IF EXISTS "Users can update their own notifications (mark as read)"
      ON public.notifications;

    CREATE POLICY "Users can view their own notifications"
      ON public.notifications FOR SELECT
      USING (
        recipient_id = auth.uid()
        OR recipient_role = 'ALL'
        OR (recipient_role = 'SUPER_ADMIN' AND public.has_role(ARRAY['Super Admin']))
        OR (recipient_role = 'ADMIN' AND public.has_role(ARRAY['Admin', 'Super Admin']))
      );

    CREATE POLICY "Authenticated users can insert notifications"
      ON public.notifications FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');

    CREATE POLICY "Users can update their own notifications (mark as read)"
      ON public.notifications FOR UPDATE
      USING (recipient_id = auth.uid() OR recipient_role = 'ALL' OR recipient_role IS NULL);
  END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 8: Harden account_setup_tokens (if table exists)
-- ══════════════════════════════════════════════════════════════════════════════
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public'
             AND table_name = 'account_setup_tokens') THEN

    DROP POLICY IF EXISTS "Service role insert" ON public.account_setup_tokens;
    DROP POLICY IF EXISTS "Service role delete" ON public.account_setup_tokens;

    COMMENT ON POLICY "Public read by token"
      ON public.account_setup_tokens IS
      'Anyone can SELECT account_setup_tokens (lookup by token during setup flow).';
  END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 9: Add RLS to email_outbox (if table exists)
-- ══════════════════════════════════════════════════════════════════════════════
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public'
             AND table_name = 'email_outbox') THEN

    ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Staff can view email outbox" ON public.email_outbox;
    DROP POLICY IF EXISTS "System can insert email outbox" ON public.email_outbox;

    CREATE POLICY "Staff can view email outbox"
      ON public.email_outbox FOR SELECT
      USING (auth.role() = 'authenticated');

    CREATE POLICY "System can insert email outbox"
      ON public.email_outbox FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 10: Verify centers hardened policies are in place
-- ══════════════════════════════════════════════════════════════════════════════
-- Centers should already have hardened policies from harden_rls.sql,
-- but we drop any leftover dev policies for safety.
DROP POLICY IF EXISTS "Public centers are viewable by everyone" ON public.centers;
DROP POLICY IF EXISTS "Admins can manage centers" ON public.centers;
