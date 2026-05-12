-- Pending password reset queue (Staff Directory → Pending Resets).
-- Apply in Supabase: SQL Editor → New query → paste → Run,
-- or: supabase db push (if this repo is linked to the project).

CREATE TABLE IF NOT EXISTS public.password_reset_requests (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_email  TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by TEXT,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

ALTER TABLE public.password_reset_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reset_requests_select" ON public.password_reset_requests;
DROP POLICY IF EXISTS "reset_requests_insert" ON public.password_reset_requests;
DROP POLICY IF EXISTS "reset_requests_update" ON public.password_reset_requests;
CREATE POLICY "reset_requests_select" ON public.password_reset_requests FOR SELECT USING (true);
CREATE POLICY "reset_requests_insert" ON public.password_reset_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "reset_requests_update" ON public.password_reset_requests FOR UPDATE USING (true);

CREATE INDEX IF NOT EXISTS idx_reset_requests_status ON public.password_reset_requests(status);
CREATE INDEX IF NOT EXISTS idx_reset_requests_email  ON public.password_reset_requests(user_email);
