-- THE SUPER-FIX: Clean and Replace Email System
-- Run this in your Supabase SQL Editor to kill any hardcoded logic and replace it with a robust system.

-- 1. DROP any existing triggers on email_outbox (just in case)
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE event_object_table = 'email_outbox') LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON ' || r.event_object_table;
    END LOOP;
END $$;

-- 2. Create a CLEAN replacement function that is 100% dynamic
CREATE OR REPLACE FUNCTION public.send_dynamic_email_v2()
RETURNS trigger AS $$
DECLARE
  api_key TEXT := 'mlsn.11f1310f9498cde8af14492685ebe997ae8246880b05c5e9cb62323217b4204e';
  payload JSONB;
BEGIN
  -- We pull the recipient dynamically from the NEW row
  -- NO HARDCODED EMAILS HERE!
  payload := jsonb_build_object(
    'from', jsonb_build_object('email', 'noreply@nsbsa.org.za', 'name', 'NSBSA Admin'),
    'to', jsonb_build_array(
      jsonb_build_object('email', NEW.to_email, 'name', COALESCE(NEW.metadata->>'full_name', 'NSBSA Staff'))
    ),
    'subject', NEW.subject,
    'html', NEW.html_content
  );

  -- Use the HTTP extension (common in Supabase)
  PERFORM extensions.http_post(
    'https://api.mailersend.com/v1/email',
    payload::text,
    'application/json',
    jsonb_build_object('Authorization', 'Bearer ' || api_key)::text
  );

  -- Log success
  UPDATE public.email_outbox SET status = 'sent', processed_at = now() WHERE id = NEW.id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log failure details
  UPDATE public.email_outbox SET status = 'failed', last_error = SQLERRM WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Attach the NEW dynamic trigger
CREATE TRIGGER tr_send_dynamic_email_v2
AFTER INSERT ON public.email_outbox
FOR EACH ROW
WHEN (NEW.status = 'pending')
EXECUTE FUNCTION public.send_dynamic_email_v2();

-- 4. Check for any OTHER triggers on the profiles table that might be interfering
SELECT 
    trigger_name, 
    event_object_table, 
    action_statement 
FROM 
    information_schema.triggers 
WHERE 
    event_object_table = 'profiles';
