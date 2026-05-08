-- Supabase Database Schema for NSBSA Admin

-- 1. Create groups table
CREATE TABLE public.groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reference_number TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Create vendors table
CREATE TABLE public.vendors (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    whatsapp_number TEXT,
    id_number TEXT,
    business_type TEXT,
    df_name TEXT,
    gender TEXT,
    reference_number TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Create loans table
CREATE TABLE public.loans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL,
    duration_months INTEGER NOT NULL,
    monthly_payment NUMERIC NOT NULL,
    status TEXT NOT NULL DEFAULT 'Active', -- Active, Completed, Defaulted
    initiation_fee NUMERIC,
    monthly_admin_fee NUMERIC,
    penalty_fee NUMERIC,
    opening_amount NUMERIC,
    first_instalment_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Create payments table
CREATE TABLE public.payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    loan_id UUID REFERENCES public.loans(id) ON DELETE CASCADE,
    amount_paid NUMERIC NOT NULL,
    date_paid TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    balance_remaining NUMERIC NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Create announcements table
CREATE TABLE public.announcements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    message TEXT NOT NULL,
    target_group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL, -- nullable for global announcements
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Note: Since this is an admin dashboard, we will temporarily allow anon access
-- FOR DEVELOPMENT PURPOSES ONLY. IN PRODUCTION, configure proper RLS policies
-- based on authenticated user roles.

CREATE POLICY "Enable read access for all users" ON public.groups FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.groups FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.groups FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.groups FOR DELETE USING (true);

CREATE POLICY "Enable read access for all users" ON public.vendors FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.vendors FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.vendors FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.vendors FOR DELETE USING (true);

CREATE POLICY "Enable read access for all users" ON public.loans FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.loans FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.loans FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.loans FOR DELETE USING (true);

CREATE POLICY "Enable read access for all users" ON public.payments FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.payments FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.payments FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.payments FOR DELETE USING (true);

CREATE POLICY "Enable read access for all users" ON public.announcements FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.announcements FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.announcements FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.announcements FOR DELETE USING (true);
