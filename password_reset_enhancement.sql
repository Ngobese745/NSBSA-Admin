-- Update password_reset_requests to support status 'completed' and rejection reasons
ALTER TABLE public.password_reset_requests 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
ADD COLUMN IF NOT EXISTS reviewed_by TEXT,
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

-- Ensure status check includes 'completed'
-- Note: This might fail if the constraint is named differently or doesn't exist, 
-- but it's good practice to ensure the schema matches the code.
DO $$ 
BEGIN
    ALTER TABLE public.password_reset_requests 
    DROP CONSTRAINT IF EXISTS password_reset_requests_status_check;
    
    ALTER TABLE public.password_reset_requests 
    ADD CONSTRAINT password_reset_requests_status_check 
    CHECK (status IN ('pending', 'approved', 'completed', 'rejected'));
END $$;
