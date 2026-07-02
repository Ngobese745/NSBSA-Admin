-- ──────────────────────────────────────────────────────────────────────────────
-- Reminder Log Table
-- ──────────────────────────────────────────────────────────────────────────────
-- Tracks every automated reminder sent (payment reminders, grace-period-end
-- notices) for auditability and deduplication.
--
-- Used by:
--   - GracePeriodReminderService (lib/services/grace_period_reminder_service.dart)
--   - PaymentReminderService (lib/services/payment_reminder_service.dart) via
--     communication_logs (this table mirrors that data for the grace flow)
--   - process-grace-period-reminders Edge Function
--
-- The `sent` boolean and `status` text coexist to serve both the Dart service
-- (which writes `sent` and `error`) and the `ReminderLogModel` (which
-- reads `status` and `error_message`).  New code should prefer the
-- status/error_message convention.
-- ──────────────────────────────────────────────────────────────────────────────

create table if not exists reminder_log (
  id              uuid default gen_random_uuid() primary key,
  vendor_id       text not null,
  vendor_name     text not null default '',
  vendor_phone    text not null default '',
  vendor_email    text not null default '',
  vendor_whatsapp text not null default '',
  loan_amount     double precision not null default 0,
  balance         double precision not null default 0,
  loan_ref        text not null,
  due_date        timestamp with time zone,
  reminder_type   text not null default 'initial',   -- 'initial', 'follow_up', 'grace_period_end'
  channel         text not null default 'multi',      -- 'Email','WhatsApp','SMS','multi'
  status          text not null default 'pending',    -- 'pending','sent','delivered','failed'
  sent            boolean not null default false,      -- convenience flag (Dart grace service)
  error           text,                                -- raw error from Dart service
  error_message   text,                                -- structured error for model compatibility
  created_at      timestamp with time zone not null default now()
);

-- Index for deduplication lookups (grace period service + Edge Function)
create index if not exists idx_reminder_log_lookup
  on reminder_log (loan_ref, reminder_type);

-- Index for vendor-specific history queries
create index if not exists idx_reminder_log_vendor
  on reminder_log (vendor_id, created_at desc);

-- Enable RLS
alter table reminder_log enable row level security;

-- Admins can read all reminder logs
create policy "Admins can read reminder_log"
  on reminder_log for select
  using (
    auth.role() = 'service_role'
    or exists (
      select 1 from profiles
      where id = auth.uid()
        and role in ('Super Admin', 'Admin')
    )
  );

-- Only service_role can insert/update
create policy "Service role can insert reminder_log"
  on reminder_log for insert
  with check (auth.role() = 'service_role');

create policy "Service role can update reminder_log"
  on reminder_log for update
  using (auth.role() = 'service_role');
