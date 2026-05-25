-- Feature flag access control: allow selective bypass when a feature is disabled.
-- Run in Supabase SQL Editor or via supabase db push.

-- ─── Add access control columns to feature_flags ───
ALTER TABLE public.feature_flags
    ADD COLUMN IF NOT EXISTS allowed_roles TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS allowed_users TEXT[] NOT NULL DEFAULT '{}';

-- Seed the admin email into existing feature flags so Super Admin can always test
UPDATE public.feature_flags
SET allowed_users = ARRAY['colane@mwelasefin.co.za']
WHERE NOT ('colane@mwelasefin.co.za' = ANY (COALESCE(allowed_users, '{}')));
