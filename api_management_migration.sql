-- NSBSA API Management Schema

-- 1. API Keys Table
CREATE TABLE IF NOT EXISTS public.api_keys (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    service_name TEXT NOT NULL, -- 'wesender', 'smsworx', etc.
    label TEXT NOT NULL, -- e.g., 'Production WeSender Key'
    api_key TEXT NOT NULL, -- Stored as text, Supabase encrypts at rest.
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'revoked'
    is_revoked BOOLEAN DEFAULT false,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES auth.users(id),
);

-- 1.1 Partial Unique Index (only one active key per service)
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_service_key 
ON public.api_keys (service_name) 
WHERE (status = 'active');

-- 2. Audit Logs for API Keys
-- Note: Reusing existing developer_action_log if possible, 
-- or creating a specialized one for compliance.
-- I will use the general developer_action_log for consistency.

-- 3. Row-Level Security
ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;

-- Only Super Admin and allowlisted developers can access this table
CREATE POLICY "Super Admin and Developers can manage API keys"
    ON public.api_keys
    FOR ALL
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'Super Admin' 
        OR auth.jwt() ->> 'email' = 'colane@mwelasefin.co.za'
    )
    WITH CHECK (
        auth.jwt() ->> 'role' = 'Super Admin'
        OR auth.jwt() ->> 'email' = 'colane@mwelasefin.co.za'
    );

-- 4. Helper function for masking (for UI display if needed via RPC, 
-- but we can do masking in Flutter as well)
CREATE OR REPLACE FUNCTION mask_api_key(key TEXT) RETURNS TEXT AS $$
BEGIN
    IF LENGTH(key) <= 8 THEN
        RETURN '••••' || RIGHT(key, 2);
    ELSE
        RETURN LEFT(key, 4) || '••••••••' || RIGHT(key, 4);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
