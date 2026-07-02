-- DF Approval Workflow: vendors and groups require Admin approval
-- when created by a Development Facilitator.

-- ── Vendors ──
ALTER TABLE public.vendors
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'Approved',
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.vendors
  DROP CONSTRAINT IF EXISTS vendors_approval_status_check,
  ADD CONSTRAINT vendors_approval_status_check
    CHECK (approval_status IN ('Pending', 'Approved', 'Rejected'));

-- ── Groups ──
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'Approved',
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.groups
  DROP CONSTRAINT IF EXISTS groups_approval_status_check,
  ADD CONSTRAINT groups_approval_status_check
    CHECK (approval_status IN ('Pending', 'Approved', 'Rejected'));

-- ── Indexes for approval queue queries ──
CREATE INDEX IF NOT EXISTS idx_vendors_approval_status ON public.vendors(approval_status);
CREATE INDEX IF NOT EXISTS idx_groups_approval_status ON public.groups(approval_status);
CREATE INDEX IF NOT EXISTS idx_vendors_created_by ON public.vendors(created_by);
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON public.groups(created_by);

-- ── RLS: DF can only see Approved records; Admins/SuperAdmins see all ──
-- Vendors
DROP POLICY IF EXISTS "Df view only approved vendors" ON public.vendors;
CREATE POLICY "Df view only approved vendors" ON public.vendors
  FOR SELECT USING (
    auth.uid() IS NULL
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('Super Admin', 'Admin'))
    OR approval_status = 'Approved'
  );

-- Groups
DROP POLICY IF EXISTS "Df view only approved groups" ON public.groups;
CREATE POLICY "Df view only approved groups" ON public.groups
  FOR SELECT USING (
    auth.uid() IS NULL
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('Super Admin', 'Admin'))
    OR approval_status = 'Approved'
  );

-- ── Trigger: auto-set approval_status to Pending when DF creates a vendor/group ──
CREATE OR REPLACE FUNCTION public.set_pending_for_df()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  creator_role TEXT;
BEGIN
  SELECT role INTO creator_role FROM public.profiles WHERE id = auth.uid();

  IF creator_role = 'Development Facilitator' THEN
    NEW.approval_status := 'Pending';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vendor_set_pending_for_df ON public.vendors;
CREATE TRIGGER trg_vendor_set_pending_for_df
  BEFORE INSERT ON public.vendors
  FOR EACH ROW
  EXECUTE FUNCTION public.set_pending_for_df();

DROP TRIGGER IF EXISTS trg_group_set_pending_for_df ON public.groups;
CREATE TRIGGER trg_group_set_pending_for_df
  BEFORE INSERT ON public.groups
  FOR EACH ROW
  EXECUTE FUNCTION public.set_pending_for_df();
