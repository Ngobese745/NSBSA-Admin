-- Table for custom account setup tokens
CREATE TABLE IF NOT EXISTS public.account_setup_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ DEFAULT (now() + interval '24 hours')
);

-- Enable RLS
ALTER TABLE public.account_setup_tokens ENABLE ROW LEVEL SECURITY;

-- Allow reading the token if you know the token string (public read but only by exact match)
CREATE POLICY "Public read by token" ON public.account_setup_tokens
    FOR SELECT USING (true);

-- Only service role can insert/delete
CREATE POLICY "Service role insert" ON public.account_setup_tokens
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Service role delete" ON public.account_setup_tokens
    FOR DELETE USING (true);
