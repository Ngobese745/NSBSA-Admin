-- Add disbursed_date column to loans table for importing the official
-- loan disbursement date from Excel spreadsheets.
-- Safe to re-run (idempotent: ADD COLUMN IF NOT EXISTS).

ALTER TABLE public.loans
  ADD COLUMN IF NOT EXISTS disbursed_date DATE;
