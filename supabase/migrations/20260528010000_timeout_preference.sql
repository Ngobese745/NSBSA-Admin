-- ──────────────────────────────────────────────────────────────────────────────
-- Session Timeout Preference for Profiles
-- ──────────────────────────────────────────────────────────────────────────────
-- Adds columns to the profiles table so users can configure their own
-- inactivity timeout duration or disable the timeout entirely.
--
-- Columns added:
--   timeout_minutes  INT      – custom timeout in minutes (NULL = use default 15)
--   timeout_disabled BOOLEAN  – if TRUE, inactivity timeout is disabled
-- ──────────────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS timeout_minutes INT,
  ADD COLUMN IF NOT EXISTS timeout_disabled BOOLEAN NOT NULL DEFAULT FALSE;
