-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- 'SYSTEM', 'ACTIVITY', 'FINANCIAL', 'HIERARCHY'
    recipient_role TEXT, -- 'SUPER_ADMIN', 'ADMIN', 'GROUP_LEADER', 'ALL'
    recipient_id UUID REFERENCES auth.users(id), -- Optional: for targeted user notifications
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own notifications"
ON notifications FOR SELECT
USING (
    recipient_id = auth.uid() OR 
    recipient_role = 'ALL' OR
    (recipient_role = 'SUPER_ADMIN' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'Super Admin')) OR
    (recipient_role = 'ADMIN' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('Admin', 'Super Admin')))
);

CREATE POLICY "Users can update their own notifications (mark as read)"
ON notifications FOR UPDATE
USING (recipient_id = auth.uid() OR recipient_role = 'ALL' OR recipient_role IS NULL);

-- Index for performance
CREATE INDEX idx_notifications_recipient_role ON notifications(recipient_role);
CREATE INDEX idx_notifications_recipient_id ON notifications(recipient_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
