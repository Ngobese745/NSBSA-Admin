-- SQL Migration to add status tracking to email_outbox
-- This allows us to debug why emails are not being delivered to all domains.

-- 1. Ensure columns exist for status tracking
ALTER TABLE public.email_outbox 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS last_error TEXT,
ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP WITH TIME ZONE;

-- 2. Add an index for better performance when processing
CREATE INDEX IF NOT EXISTS idx_email_outbox_status ON public.email_outbox(status);

-- 3. Update existing records to 'pending' if status is null
UPDATE public.email_outbox SET status = 'pending' WHERE status IS NULL;
