-- Immutable account audit trail (User Management → Audit Log).
-- Apply in Supabase: SQL Editor → paste → Run,
-- or: supabase db push (if this repo is linked to the project).

CREATE TABLE IF NOT EXISTS public.account_audit_log (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_type     TEXT NOT NULL,
    target_email   TEXT NOT NULL,
    operator_email TEXT,
    metadata       JSONB,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

ALTER TABLE public.account_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "audit_log_select" ON public.account_audit_log;
DROP POLICY IF EXISTS "audit_log_insert" ON public.account_audit_log;
CREATE POLICY "audit_log_select" ON public.account_audit_log FOR SELECT USING (true);
CREATE POLICY "audit_log_insert" ON public.account_audit_log FOR INSERT WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_audit_log_event       ON public.account_audit_log(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_log_target      ON public.account_audit_log(target_email);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at  ON public.account_audit_log(created_at DESC);
