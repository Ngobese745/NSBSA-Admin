-- NSBSA Marketing Module Schema

-- 1. Marketing Templates
CREATE TABLE IF NOT EXISTS public.marketing_templates (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    name TEXT NOT NULL,
    type TEXT NOT NULL, -- 'email', 'sms', 'whatsapp'
    subject TEXT,
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Marketing Campaigns
CREATE TABLE IF NOT EXISTS public.marketing_campaigns (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL, -- 'email', 'sms', 'whatsapp'
    status TEXT DEFAULT 'draft', -- 'draft', 'scheduled', 'sending', 'completed', 'cancelled'
    target_segment JSONB DEFAULT '{}'::jsonb, -- Filter criteria
    template_id UUID REFERENCES public.marketing_templates(id),
    scheduled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    engagement_stats JSONB DEFAULT '{"sent": 0, "delivered": 0, "opened": 0, "clicked": 0}'::jsonb
);

-- 3. Marketing Leads
CREATE TABLE IF NOT EXISTS public.marketing_leads (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    source TEXT, -- 'website', 'referral', 'event'
    status TEXT DEFAULT 'new', -- 'new', 'contacted', 'interested', 'converted', 'lost'
    notes TEXT,
    assigned_to UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    converted_at TIMESTAMPTZ
);

-- 4. Marketing Interaction Logs (Tracking & Engagement)
CREATE TABLE IF NOT EXISTS public.marketing_logs (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    campaign_id UUID REFERENCES public.marketing_campaigns(id),
    vendor_id UUID REFERENCES public.vendors(id),
    lead_id UUID REFERENCES public.marketing_leads(id),
    type TEXT NOT NULL, -- 'email', 'sms', 'whatsapp'
    status TEXT DEFAULT 'sent', -- 'sent', 'delivered', 'opened', 'clicked', 'failed'
    error_message TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Opt-out Tracking (Compliance)
CREATE TABLE IF NOT EXISTS public.marketing_opt_outs (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    email TEXT,
    phone TEXT,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(email),
    UNIQUE(phone)
);

-- RLS Policies
ALTER TABLE public.marketing_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_opt_outs ENABLE ROW LEVEL SECURITY;

-- Role based access (Marketing, Admin, Super Admin)
CREATE POLICY "Allow marketing access to templates" ON public.marketing_templates
    FOR ALL USING (
        auth.jwt() ->> 'role' IN ('Marketing', 'Admin', 'Super Admin')
    );

CREATE POLICY "Allow marketing access to campaigns" ON public.marketing_campaigns
    FOR ALL USING (
        auth.jwt() ->> 'role' IN ('Marketing', 'Admin', 'Super Admin')
    );

CREATE POLICY "Allow marketing access to leads" ON public.marketing_leads
    FOR ALL USING (
        auth.jwt() ->> 'role' IN ('Marketing', 'Admin', 'Super Admin')
    );

CREATE POLICY "Allow marketing access to logs" ON public.marketing_logs
    FOR ALL USING (
        auth.jwt() ->> 'role' IN ('Marketing', 'Admin', 'Super Admin')
    );

CREATE POLICY "Allow marketing access to opt_outs" ON public.marketing_opt_outs
    FOR ALL USING (
        auth.jwt() ->> 'role' IN ('Marketing', 'Admin', 'Super Admin')
    );

-- 6. Feature Flags
INSERT INTO feature_flags (feature_key, label, enabled, sort_order)
VALUES ('marketing', 'Marketing Module', true, 80)
ON CONFLICT (feature_key) DO UPDATE 
SET label = EXCLUDED.label;
