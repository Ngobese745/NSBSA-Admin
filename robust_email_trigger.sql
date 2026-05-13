-- SQL Migration: Robust Email Delivery Trigger
-- This replaces the UI-based Webhook with a dynamic SQL trigger to ensure all recipients receive emails.

-- 1. Enable the http extension (Supabase built-in)
CREATE EXTENSION IF NOT EXISTS "http" WITH SCHEMA "extensions";

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

    -- Perform the HTTP POST request using pgsql-http syntax
    PERFORM extensions.http((
        'POST',
        'https://api.mailersend.com/v1/email',
        ARRAY[extensions.http_header('Authorization', 'Bearer ' || api_key)],
        'application/json',
        payload::text
    )::extensions.http_request);

    -- Update row status to indicate it was processed
    UPDATE public.email_outbox 
    SET status = 'sent', processed_at = now()
    WHERE id = NEW.id;

    -- Sync status with communication_logs
    IF NEW.log_id IS NOT NULL THEN
        UPDATE public.communication_logs
        SET status = 'sent'
        WHERE id = NEW.log_id;
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Capture any errors back into the table for debugging
    UPDATE public.email_outbox 
    SET status = 'failed', last_error = SQLERRM
    WHERE id = NEW.id;

    -- Sync failed status with communication_logs
    IF NEW.log_id IS NOT NULL THEN
        UPDATE public.communication_logs
        SET status = 'failed', error_message = COALESCE(SQLERRM, 'Email delivery failed')
        WHERE id = NEW.log_id;
    END IF;

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
