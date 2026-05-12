-- Developer controls: system banners, feature flags, audit trail.
-- Run in Supabase SQL Editor or via supabase db push.

-- ─── System banners (maintenance / under development notices) ───
CREATE TABLE IF NOT EXISTS public.system_banners (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    banner_type   TEXT NOT NULL CHECK (banner_type IN ('system_update', 'under_development')),
    title         TEXT NOT NULL,
    message       TEXT NOT NULL,
    severity      TEXT NOT NULL DEFAULT 'warning'
                      CHECK (severity IN ('info', 'warning', 'critical')),
    is_enabled    BOOLEAN NOT NULL DEFAULT false,
    starts_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at       TIMESTAMPTZ, -- NULL = no automatic end
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_system_banners_enabled ON public.system_banners(is_enabled, starts_at DESC);

-- ─── Feature flags (module on/off) ───
CREATE TABLE IF NOT EXISTS public.feature_flags (
    feature_key TEXT PRIMARY KEY,
    enabled     BOOLEAN NOT NULL DEFAULT true,
    label       TEXT NOT NULL,
    sort_order  INT NOT NULL DEFAULT 0,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

INSERT INTO public.feature_flags (feature_key, enabled, label, sort_order) VALUES
    ('dashboard', true, 'Dashboard', 0),
    ('groups', true, 'Groups', 1),
    ('vendors', true, 'Vendors', 2),
    ('loans', true, 'Loans', 3),
    ('payments', true, 'Payments', 4),
    ('analytics', true, 'Advanced Analytics', 5),
    ('reports', true, 'Financial Reports', 6),
    ('import', true, 'Import Data', 7),
    ('user_management', true, 'User Management', 8)
ON CONFLICT (feature_key) DO NOTHING;

-- ─── Developer action audit ───
CREATE TABLE IF NOT EXISTS public.developer_action_log (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    developer_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    developer_email  TEXT,
    action_type      TEXT NOT NULL,
    resource_type    TEXT,
    resource_id      TEXT,
    payload          JSONB,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_developer_action_log_created ON public.developer_action_log(created_at DESC);

-- ─── RLS ───
ALTER TABLE public.system_banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.developer_action_log ENABLE ROW LEVEL SECURITY;

-- Any signed-in user can read banners & flags (for UI + banner strip)
DROP POLICY IF EXISTS "system_banners_select_auth" ON public.system_banners;
CREATE POLICY "system_banners_select_auth" ON public.system_banners
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "feature_flags_select_auth" ON public.feature_flags;
CREATE POLICY "feature_flags_select_auth" ON public.feature_flags
    FOR SELECT TO authenticated USING (true);

-- Super Admin OR allowlisted developer email may mutate banners / flags / logs
DROP POLICY IF EXISTS "system_banners_write_dev" ON public.system_banners;
CREATE POLICY "system_banners_write_dev" ON public.system_banners
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND (
                  p.role = 'Super Admin'
                  OR lower(trim(COALESCE(p.email, ''))) = 'colane@mwelasefin.co.za'
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND (
                  p.role = 'Super Admin'
                  OR lower(trim(COALESCE(p.email, ''))) = 'colane@mwelasefin.co.za'
              )
        )
    );

DROP POLICY IF EXISTS "feature_flags_write_dev" ON public.feature_flags;
CREATE POLICY "feature_flags_write_dev" ON public.feature_flags
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND (
                  p.role = 'Super Admin'
                  OR lower(trim(COALESCE(p.email, ''))) = 'colane@mwelasefin.co.za'
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND (
                  p.role = 'Super Admin'
                  OR lower(trim(COALESCE(p.email, ''))) = 'colane@mwelasefin.co.za'
              )
        )
    );

DROP POLICY IF EXISTS "developer_action_log_select_dev" ON public.developer_action_log;
CREATE POLICY "developer_action_log_select_dev" ON public.developer_action_log
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND (
                  p.role = 'Super Admin'
                  OR lower(trim(COALESCE(p.email, ''))) = 'colane@mwelasefin.co.za'
              )
        )
    );

DROP POLICY IF EXISTS "developer_action_log_insert_dev" ON public.developer_action_log;
CREATE POLICY "developer_action_log_insert_dev" ON public.developer_action_log
    FOR INSERT TO authenticated
    WITH CHECK (
        developer_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND (
                  p.role = 'Super Admin'
                  OR lower(trim(COALESCE(p.email, ''))) = 'colane@mwelasefin.co.za'
              )
        )
    );
