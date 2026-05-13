-- SQL Migration: Robust Email Delivery Trigger
-- This replaces the UI-based Webhook with a dynamic SQL trigger to ensure all recipients receive emails.

-- 1. Enable the net extension (Supabase built-in)
CREATE EXTENSION IF NOT EXISTS "net" WITH SCHEMA "extensions";

-- 2. Create the processing function
CREATE OR REPLACE FUNCTION public.process_email_outbox()
RETURNS trigger AS $$
DECLARE
    api_key TEXT := 'mlsn.11f1310f9498cde8af14492685ebe997ae8246880b05c5e9cb62323217b4204e'; -- Your API Key
    payload JSONB;
BEGIN
    -- Construct the MailerSend payload dynamically from the row data
    payload := jsonb_build_object(
        'from', jsonb_build_object(
            'email', 'noreply@nsbsa.org.za',
            'name', 'NSBSA Admin'
        ),
        'to', jsonb_build_array(
            jsonb_build_object(
                'email', NEW.to_email,
                'name', COALESCE(NEW.metadata->>'full_name', NEW.to_email)
            )
        ),
        'subject', NEW.subject,
        'html', NEW.html_content
    );

    -- Perform the HTTP POST request via extensions.net_http_get/post
    PERFORM extensions.http_post(
        url := 'https://api.mailersend.com/v1/email',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || api_key
        ),
        body := payload
    );

    -- Update row status to indicate it was processed
    UPDATE public.email_outbox 
    SET status = 'sent', processed_at = now()
    WHERE id = NEW.id;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Capture any errors back into the table for debugging
    UPDATE public.email_outbox 
    SET status = 'failed', last_error = SQLERRM
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create the trigger
DROP TRIGGER IF EXISTS tr_process_email ON public.email_outbox;
CREATE TRIGGER tr_process_email
AFTER INSERT ON public.email_outbox
FOR EACH ROW
WHEN (NEW.status = 'pending')
EXECUTE FUNCTION public.process_email_outbox();
