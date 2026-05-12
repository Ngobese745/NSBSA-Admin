-- Add status column to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active';

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
