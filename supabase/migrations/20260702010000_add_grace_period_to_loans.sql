-- ──────────────────────────────────────────────────────────────────────────────
-- Add Grace Period support to the loans table
-- ──────────────────────────────────────────────────────────────────────────────
-- Allows loans to be created with an optional grace period during which the
-- client only pays the initiation fee. The first regular instalment is
-- scheduled for `loan_creation_date + grace_period_months + 1 month`.
-- During the grace period, the system automatically sends the client a
-- payment-start reminder via email / WhatsApp / SMS when the grace period
-- expires.
--
-- Idempotent: only runs the ALTER if the `loans` table already exists. This
-- lets the migration be safely replayed on fresh databases before the
-- initial schema has been applied.
-- ──────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM   information_schema.tables
    WHERE  table_schema = 'public'
    AND    table_name   = 'loans'
  ) THEN
    ALTER TABLE loans
      ADD COLUMN IF NOT EXISTS grace_period_enabled  BOOLEAN NOT NULL DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS grace_period_months  INTEGER,
      ADD COLUMN IF NOT EXISTS first_payment_date    DATE,
      ADD COLUMN IF NOT EXISTS interest_rate         DOUBLE PRECISION;

    -- Backfill: mirror first_instalment_date for existing loans so
    -- first_payment_date is never NULL.
    UPDATE loans
    SET    first_payment_date = first_instalment_date
    WHERE  first_payment_date IS NULL
      AND  first_instalment_date IS NOT NULL;

    -- Helpful index for the auto-reminder cron / scheduler.
    CREATE INDEX IF NOT EXISTS idx_loans_grace_period
      ON loans (first_payment_date)
      WHERE grace_period_enabled = TRUE;
  END IF;
END $$;
