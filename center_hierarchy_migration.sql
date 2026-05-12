-- Migration: Introduce Centers and Leadership Hierarchy

-- 1. Create centers table
CREATE TABLE IF NOT EXISTS public.centers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    reference_number TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Modify groups table to link to centers
-- Note: Making it nullable first to handle existing data, then we can enforce NOT NULL
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS center_id UUID REFERENCES public.centers(id) ON DELETE SET NULL;

-- 3. Create leadership table for both Centers and Groups
CREATE TABLE IF NOT EXISTS public.leadership (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    
    CONSTRAINT valid_leadership_role CHECK (role IN ('Chairperson', 'Secretary', 'Treasurer')),
    CONSTRAINT one_target_only CHECK (
        (center_id IS NOT NULL AND group_id IS NULL) OR
        (center_id IS NULL AND group_id IS NOT NULL)
    ),
    -- Ensure only one of each role per Center/Group
    UNIQUE(center_id, role),
    UNIQUE(group_id, role)
);

-- Enable RLS
ALTER TABLE public.centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leadership ENABLE ROW LEVEL SECURITY;

-- Basic Policies (Allow all for now, refined by roles later)
CREATE POLICY "Public centers are viewable by everyone" ON public.centers FOR SELECT USING (true);
CREATE POLICY "Public leadership is viewable by everyone" ON public.leadership FOR SELECT USING (true);
CREATE POLICY "Admins can manage centers" ON public.centers FOR ALL USING (true);
CREATE POLICY "Admins can manage leadership" ON public.leadership FOR ALL USING (true);

-- Seed a Default Center for existing groups
INSERT INTO public.centers (name, reference_number) 
VALUES ('Main Center', 'CTR-001')
ON CONFLICT (name) DO NOTHING;

-- Link existing groups to the default center
UPDATE public.groups SET center_id = (SELECT id FROM public.centers WHERE name = 'Main Center') WHERE center_id IS NULL;

-- Now we can theoretically enforce NOT NULL if needed, but let's keep it safe for now.
-- ALTER TABLE public.groups ALTER COLUMN center_id SET NOT NULL;
