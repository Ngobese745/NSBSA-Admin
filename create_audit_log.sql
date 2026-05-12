-- Create system_audit_log table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.system_audit_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    action_type TEXT NOT NULL,
    performed_by TEXT NOT NULL,
    affected_entity TEXT NOT NULL,
    description TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.system_audit_log ENABLE ROW LEVEL SECURITY;

-- Allow Super Admin and Admin to read logs
CREATE POLICY "Admins can view system audit logs" 
ON public.system_audit_log FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() 
        AND role IN ('Super Admin', 'Admin')
    )
);

-- Allow all authenticated users to insert logs (so their actions are recorded)
CREATE POLICY "Authenticated users can insert audit logs" 
ON public.system_audit_log FOR INSERT 
WITH CHECK (auth.uid() IS NOT NULL);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_system_audit_log_action ON public.system_audit_log(action_type);
CREATE INDEX IF NOT EXISTS idx_system_audit_log_timestamp ON public.system_audit_log(timestamp DESC);
