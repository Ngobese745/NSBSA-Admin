-- hardening_rls.sql
-- Run this in your Supabase SQL Editor to tighten security.

-- 1. Helper function to check user roles from public.profiles
CREATE OR REPLACE FUNCTION public.has_role(required_roles text[])
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = ANY(required_roles)
    AND status = 'Active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Revoke all previous open policies
-- (You may need to drop existing policies manually if names vary, 
-- but these target the ones found in schema.sql)

DO $$ 
DECLARE 
    t text;
BEGIN
    FOR t IN (SELECT table_name FROM information_schema.tables WHERE table_schema = 'public') 
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Enable read access for all users" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Enable insert for all users" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Enable update for all users" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Enable delete for all users" ON public.%I', t);
    END LOOP;
END $$;

-- 3. Define Tightened Policies

-- GROUPS
DROP POLICY IF EXISTS "Staff can view groups" ON public.groups;
CREATE POLICY "Staff can view groups" ON public.groups FOR SELECT 
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage groups" ON public.groups;
CREATE POLICY "Admins can manage groups" ON public.groups FOR ALL
USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));

-- VENDORS
DROP POLICY IF EXISTS "Staff can view vendors" ON public.vendors;
CREATE POLICY "Staff can view vendors" ON public.vendors FOR SELECT 
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins and Finance can manage vendors" ON public.vendors;
CREATE POLICY "Admins and Finance can manage vendors" ON public.vendors FOR ALL
USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));

-- LOANS
DROP POLICY IF EXISTS "Staff can view loans" ON public.loans;
CREATE POLICY "Staff can view loans" ON public.loans FOR SELECT 
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Finance and Admin can manage loans" ON public.loans;
CREATE POLICY "Finance and Admin can manage loans" ON public.loans FOR ALL
USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));

-- PAYMENTS & GROUP PAYMENTS
DROP POLICY IF EXISTS "Staff can view payments" ON public.payments;
CREATE POLICY "Staff can view payments" ON public.payments FOR SELECT 
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Finance and Admin can manage payments" ON public.payments;
CREATE POLICY "Finance and Admin can manage payments" ON public.payments FOR ALL
USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));

DROP POLICY IF EXISTS "Staff can view group payments" ON public.group_payments;
CREATE POLICY "Staff can view group payments" ON public.group_payments FOR SELECT 
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Finance and Admin can manage group payments" ON public.group_payments;
CREATE POLICY "Finance and Admin can manage group payments" ON public.group_payments FOR ALL
USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));

-- ANNOUNCEMENTS
DROP POLICY IF EXISTS "Staff can view announcements" ON public.announcements;
CREATE POLICY "Staff can view announcements" ON public.announcements FOR SELECT 
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Marketing and Admin can manage announcements" ON public.announcements;
CREATE POLICY "Marketing and Admin can manage announcements" ON public.announcements FOR ALL
USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Marketing']));

-- SAVINGS HISTORY (Audit log)
DROP POLICY IF EXISTS "Staff can view savings history" ON public.savings_history;
CREATE POLICY "Staff can view savings history" ON public.savings_history FOR SELECT 
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Staff can insert savings history" ON public.savings_history;
CREATE POLICY "Staff can insert savings history" ON public.savings_history FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- ACCOUNT AUDIT LOG (Immutable)
DROP POLICY IF EXISTS "Only Super Admins can view audit logs" ON public.account_audit_log;
CREATE POLICY "Only Super Admins can view audit logs" ON public.account_audit_log FOR SELECT
USING (public.has_role(ARRAY['Super Admin']));

DROP POLICY IF EXISTS "System can insert audit logs" ON public.account_audit_log;
CREATE POLICY "System can insert audit logs" ON public.account_audit_log FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- PASSWORD RESET REQUESTS
DROP POLICY IF EXISTS "Authenticated users can view reset requests" ON public.password_reset_requests;
CREATE POLICY "Authenticated users can view reset requests" ON public.password_reset_requests FOR SELECT
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Super Admins can manage reset requests" ON public.password_reset_requests;
CREATE POLICY "Super Admins can manage reset requests" ON public.password_reset_requests FOR ALL
USING (public.has_role(ARRAY['Super Admin']));

-- PROFILES (Critical)
-- (Found in schema.sql, but ensuring they are robust)
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by authenticated staff" ON public.profiles;
CREATE POLICY "Profiles are viewable by authenticated staff" ON public.profiles FOR SELECT
USING (auth.role() = 'authenticated');

-- COMMUNICATION LOGS
DROP POLICY IF EXISTS "Staff can view communication logs" ON public.communication_logs;
CREATE POLICY "Staff can view communication logs" ON public.communication_logs FOR SELECT
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "System can insert communication logs" ON public.communication_logs;
CREATE POLICY "System can insert communication logs" ON public.communication_logs FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- DOCUMENTS
DROP POLICY IF EXISTS "Staff can view documents" ON public.documents;
CREATE POLICY "Staff can view documents" ON public.documents FOR SELECT
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Staff can insert documents" ON public.documents;
CREATE POLICY "Staff can insert documents" ON public.documents FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Staff can delete documents" ON public.documents;
CREATE POLICY "Staff can delete documents" ON public.documents FOR DELETE
USING (auth.role() = 'authenticated');

-- SYSTEM AUDIT LOG
DROP POLICY IF EXISTS "Super Admins can view system audit logs" ON public.system_audit_log;
CREATE POLICY "Super Admins can view system audit logs" ON public.system_audit_log FOR SELECT
USING (public.has_role(ARRAY['Super Admin']));

DROP POLICY IF EXISTS "System can insert system audit logs" ON public.system_audit_log;
CREATE POLICY "System can insert system audit logs" ON public.system_audit_log FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- CENTERS
DROP POLICY IF EXISTS "Staff can view centers" ON public.centers;
CREATE POLICY "Staff can view centers" ON public.centers FOR SELECT
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage centers" ON public.centers;
CREATE POLICY "Admins can manage centers" ON public.centers FOR ALL
USING (public.has_role(ARRAY['Super Admin', 'Admin', 'Finance']));

-- 4. Enable RLS on all tables (Just in case)
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.password_reset_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communication_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.centers ENABLE ROW LEVEL SECURITY;
