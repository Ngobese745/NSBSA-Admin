-- ──────────────────────────────────────────────────────────────────────────────
-- Grace Period Reminder Cron Job
-- ──────────────────────────────────────────────────────────────────────────────
-- Sends a one-off payment-start reminder to clients whose loan grace period
-- ends on or before today. The matching Dart service is in
-- lib/services/grace_period_reminder_service.dart. This migration wires
-- the cron schedule to a Supabase Edge Function called
-- "process-grace-period-reminders" that mirrors the regular reminder
-- flow.
--
-- Run schedule: 09:00 every day
-- ──────────────────────────────────────────────────────────────────────────────

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

create or replace function extensions.setup_grace_period_cron()
returns void
language plpgsql
security definer
as $$
declare
  _project_url text := 'https://qgpkckkogkdvjtaoscmm.supabase.co';
  _cron_secret text := 'nsbsa-reminder-cron-2026';
  _sql_grace text;
begin
  _sql_grace := format(
    'select net.http_post(
      url := ''%s/functions/v1/process-grace-period-reminders'',
      headers := ''{"Content-Type":"application/json","Authorization":"Bearer %s"}''::jsonb,
      body := ''{}''::jsonb
    );',
    _project_url, _cron_secret
  );

  begin perform cron.unschedule('grace-period-end'); exception when others then null; end;

  perform cron.schedule('grace-period-end', '0 9 * * *', _sql_grace);
end;
$$;

select extensions.setup_grace_period_cron();
