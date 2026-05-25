-- ──────────────────────────────────────────────────────────────────────────────
-- Payment Reminder Cron Jobs
-- ──────────────────────────────────────────────────────────────────────────────
-- Schedules automated payment reminders at 08:00 (initial) and 18:00 (follow-up)
-- daily via pg_cron + pg_net.
--
-- Requirements:
--   1. pg_cron and pg_net extensions (enabled by default on Supabase)
--   2. Edge Function "process-payment-reminders" deployed
--   3. CRON_SECRET env var set via `supabase secrets set`
-- ──────────────────────────────────────────────────────────────────────────────

-- 1. Ensure extensions
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- 2. Create a helper function that builds and registers cron jobs.
--    Values are baked in at migration time, not resolved dynamically.
create or replace function extensions.setup_reminder_cron()
returns void
language plpgsql
security definer
as $$
declare
  _project_url text    := 'https://qgpkckkogkdvjtaoscmm.supabase.co';
  _cron_secret text    := 'nsbsa-reminder-cron-2026';
  _sql_initial text;
  _sql_followup text;
begin
  _sql_initial := format(
    'select net.http_post(
      url := ''%s/functions/v1/process-payment-reminders?type=initial'',
      headers := ''{"Content-Type":"application/json","Authorization":"Bearer %s"}''::jsonb,
      body := ''{}''::jsonb
    );',
    _project_url, _cron_secret
  );

  _sql_followup := format(
    'select net.http_post(
      url := ''%s/functions/v1/process-payment-reminders?type=follow_up'',
      headers := ''{"Content-Type":"application/json","Authorization":"Bearer %s"}''::jsonb,
      body := ''{}''::jsonb
    );',
    _project_url, _cron_secret
  );

  begin perform cron.unschedule('reminder-initial'); exception when others then null; end;
  begin perform cron.unschedule('reminder-follow-up'); exception when others then null; end;

  perform cron.schedule('reminder-initial',   '0 8 * * *',  _sql_initial);
  perform cron.schedule('reminder-follow-up', '0 18 * * *', _sql_followup);
end;
$$;

-- 3. Execute
select extensions.setup_reminder_cron();
