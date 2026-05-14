-- Add creator tracking to groups table
ALTER TABLE public.groups 
ADD COLUMN IF NOT EXISTS creator_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS creator_name TEXT;

-- Update existing records to mark them as created by 'System' or NULL if preferred
-- UPDATE public.groups SET creator_name = 'System' WHERE creator_name IS NULL;
