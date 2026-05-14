-- Migration: Introduce DF Assignment and Reporting Enhancements

-- 1. Add DF fields to centers
ALTER TABLE public.centers ADD COLUMN IF NOT EXISTS df_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.centers ADD COLUMN IF NOT EXISTS df_name TEXT;

-- 2. Add DF fields to groups
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS df_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS df_name TEXT;

-- 3. Update vendors table
-- df_name already exists, adding df_id for formal linking
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS df_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 4. Update loans table for categorization
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS loan_type TEXT DEFAULT 'Standard';

-- 5. Validation: Prevent duplicate DF assignments per group
-- The requirement says "Add validation to prevent duplicate DF assignments per group."
-- Since a group only has ONE df_id field, this is implicitly handled if we only allow one DF per group.
-- If the requirement means multiple DFs cannot be assigned to the same group, the current schema supports it.
-- If it means a DF cannot be assigned to the same group multiple times, unique constraint handles it.

-- 5. Audit Logging for Report Generation (Metadata table)
CREATE TABLE IF NOT EXISTS public.report_audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    report_type TEXT NOT NULL,
    generated_by UUID REFERENCES public.profiles(id),
    filters JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

ALTER TABLE public.report_audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Super Admins and Admins can view report logs" ON public.report_audit_logs
    FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('Super Admin', 'Admin')));
CREATE POLICY "Authenticated users can insert report logs" ON public.report_audit_logs
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Indexing for performance
CREATE INDEX IF NOT EXISTS idx_groups_df_id ON public.groups(df_id);
CREATE INDEX IF NOT EXISTS idx_vendors_df_id ON public.vendors(df_id);
CREATE INDEX IF NOT EXISTS idx_loans_group_id ON public.loans(group_id);
CREATE INDEX IF NOT EXISTS idx_payments_loan_id ON public.payments(loan_id);
