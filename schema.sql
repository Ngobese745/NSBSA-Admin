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
    address TEXT,
    role TEXT,
    savings_amount NUMERIC DEFAULT 0,
    savings_frequency TEXT,
    savings_start_date TIMESTAMP WITH TIME ZONE,
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
    -- Grace period: optional months before regular repayments begin
    grace_period_enabled  BOOLEAN NOT NULL DEFAULT FALSE,
    grace_period_months  INTEGER,
    first_payment_date    DATE,
    -- Interest rate percentage for audit and recalculation purposes
    interest_rate DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.group_payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    total_amount NUMERIC NOT NULL,
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Create payments table
CREATE TABLE public.payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    loan_id UUID REFERENCES public.loans(id) ON DELETE CASCADE,
    group_payment_id UUID REFERENCES public.group_payments(id) ON DELETE SET NULL,
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
ALTER TABLE public.group_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Note: Since this is an admin dashboard, we will temporarily allow anon access
-- FOR DEVELOPMENT PURPOSES ONLY. IN PRODUCTION, configure proper RLS policies
-- based on authenticated user roles.

CREATE POLICY "Enable read access for all users" ON public.group_payments FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.group_payments FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.group_payments FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.group_payments FOR DELETE USING (true);

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

-- Comments Table
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_role TEXT,
    content TEXT NOT NULL,
    mentioned_vendor_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Comments Policies
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users" ON public.comments FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.comments FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.comments FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.comments FOR DELETE USING (true);

CREATE INDEX IF NOT EXISTS idx_comments_group_id ON public.comments(group_id);
CREATE INDEX IF NOT EXISTS idx_comments_vendor_id ON public.comments(vendor_id);

-- Documents Table
CREATE TABLE IF NOT EXISTS public.documents (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_type TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Documents Policies
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users" ON public.documents FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.documents FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.documents FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.documents FOR DELETE USING (true);

CREATE INDEX IF NOT EXISTS idx_documents_group_id ON public.documents(group_id);
CREATE INDEX IF NOT EXISTS idx_documents_vendor_id ON public.documents(vendor_id);

-- 6. Create savings_history table
CREATE TABLE IF NOT EXISTS public.savings_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL,
    previous_balance NUMERIC NOT NULL,
    new_balance NUMERIC NOT NULL,
    action_type TEXT NOT NULL, -- Deposit, Withdrawal, Adjustment
    updated_by TEXT NOT NULL, -- User email or ID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for savings_history
ALTER TABLE public.savings_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users" ON public.savings_history FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.savings_history FOR INSERT WITH CHECK (true);
-- Note: Audit logs are immutable (no update or delete)

CREATE INDEX IF NOT EXISTS idx_savings_history_vendor_id ON public.savings_history(vendor_id);

-- 7. Create profiles table for user roles
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT,
    full_name TEXT,
    department TEXT,
    role TEXT NOT NULL DEFAULT 'Development Facilitator', -- Default to lowest access
    status TEXT NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    CONSTRAINT valid_role CHECK (role IN (
        'Super Admin',
        'Admin',
        'Finance',
        'Marketing',
        'Development Facilitator',
        'Verifying Operator'
    )),
    CONSTRAINT valid_profile_status CHECK (status IN ('Active', 'Blocked'))
);

-- Enable RLS for profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Super Admins can manage all profiles" ON public.profiles ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'Super Admin')
);
CREATE POLICY "Admins can update non-critical profile fields" ON public.profiles FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('Super Admin', 'Admin'))
);

-- Note: In a production app, you would refine the RLS policies for all other tables
-- to use the role-based checks. For example:
-- CREATE POLICY "Finance can update payments" ON public.payments FOR UPDATE
-- USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('Super Admin', 'Finance')));

-- ============================================================
-- 8. Automated Profile Creation Trigger
--    Automatically creates a profile record when a new user signs up.
--    Special case: colane@mwelasefin.co.za is always a Super Admin.
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', 'User'),
    CASE 
      WHEN new.email = 'colane@mwelasefin.co.za' THEN 'Super Admin'
      ELSE 'Development Facilitator'
    END
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute the function on user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Seed: Ensure the current developer account is fixed
INSERT INTO public.profiles (id, email, full_name, role)
SELECT
    id,
    email,
    COALESCE(raw_user_meta_data->>'full_name', 'Colane Ngobese'),
    'Super Admin'
FROM auth.users
WHERE email = 'colane@mwelasefin.co.za'
ON CONFLICT (id) DO UPDATE
    SET role      = 'Super Admin',
        email     = EXCLUDED.email,
        full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name);

-- ============================================================
-- 8. Password Reset Requests
--    Staff submit requests; Super Admin must approve before
--    a reset link is sent.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.password_reset_requests (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_email  TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by TEXT,            -- operator email who acted on the request
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

-- ============================================================
-- 9. Account Audit Log (IMMUTABLE)
--    Records every account creation, password set/reset event.
--    No UPDATE or DELETE policy — entries cannot be altered.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.account_audit_log (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_type     TEXT NOT NULL,   -- account_created | password_set | reset_requested | reset_approved | reset_rejected
    target_email   TEXT NOT NULL,
    operator_email TEXT,            -- who performed the action (null = self-service)
    metadata       JSONB,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

ALTER TABLE public.account_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "audit_log_select" ON public.account_audit_log;
DROP POLICY IF EXISTS "audit_log_insert" ON public.account_audit_log;
CREATE POLICY "audit_log_select" ON public.account_audit_log FOR SELECT USING (true);
CREATE POLICY "audit_log_insert" ON public.account_audit_log FOR INSERT WITH CHECK (true);
-- NOTE: No UPDATE or DELETE policy — audit logs are immutable by design.

CREATE INDEX IF NOT EXISTS idx_audit_log_event       ON public.account_audit_log(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_log_target      ON public.account_audit_log(target_email);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at  ON public.account_audit_log(created_at DESC);


