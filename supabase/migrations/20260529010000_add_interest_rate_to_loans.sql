-- ──────────────────────────────────────────────────────────────────────────────
-- Add interest_rate column to the loans table
-- ──────────────────────────────────────────────────────────────────────────────
-- Stores the automatically-selected interest rate percentage for audit and
-- recalculation purposes. The rate is looked up from a predefined table based
-- on loan amount and duration.
-- ──────────────────────────────────────────────────────────────────────────────

ALTER TABLE loans
  ADD COLUMN IF NOT EXISTS interest_rate DOUBLE PRECISION;
