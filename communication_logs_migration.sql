-- SQL Migration: Unified Communication Logging
-- This table tracks all manual and automated messages sent to vendors across all channels.

CREATE TABLE IF NOT EXISTS public.communication_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE CASCADE,
    channel TEXT NOT NULL, -- 'Email', 'WhatsApp', 'SMS'
    recipient TEXT NOT NULL, -- email address or phone number
    subject TEXT, -- only for emails
    content TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'sent', 'delivered', 'failed'
    error_message TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.communication_logs ENABLE ROW LEVEL SECURITY;

-- Policies for admin/staff to view and log communications
CREATE POLICY "Enable read access for all users" ON public.communication_logs FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.communication_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.communication_logs FOR UPDATE USING (true);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_comm_logs_vendor_id ON public.communication_logs(vendor_id);
CREATE INDEX IF NOT EXISTS idx_comm_logs_channel ON public.communication_logs(channel);
CREATE INDEX IF NOT EXISTS idx_comm_logs_created_at ON public.communication_logs(created_at DESC);

-- Update email_outbox to include a reference to communication_logs if we want to sync status
ALTER TABLE public.email_outbox ADD COLUMN IF NOT EXISTS log_id UUID REFERENCES public.communication_logs(id) ON DELETE SET NULL;
