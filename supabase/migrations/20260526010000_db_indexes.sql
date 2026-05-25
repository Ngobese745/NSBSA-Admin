-- ──────────────────────────────────────────────────────────────────────────────
-- Database Performance Indexes
-- ──────────────────────────────────────────────────────────────────────────────
-- Adds missing indexes for frequently queried columns to improve query
-- performance on centers, comments, and documents tables.
--
-- Requirements:
--   1. Run against the Supabase project database
--   2. Safe to re-run (uses IF NOT EXISTS / CONCURRENTLY)
-- ──────────────────────────────────────────────────────────────────────────────

-- Centers
CREATE INDEX IF NOT EXISTS idx_centers_name ON centers (name);
CREATE INDEX IF NOT EXISTS idx_centers_reference_number ON centers (reference_number);
CREATE INDEX IF NOT EXISTS idx_centers_df_id ON centers (df_id);

-- Comments
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON comments (created_at DESC);
-- GIN index for mentioned_vendor_ids array queries
CREATE INDEX IF NOT EXISTS idx_comments_mentioned_vendor_ids
  ON comments USING GIN (mentioned_vendor_ids);

-- Documents
CREATE INDEX IF NOT EXISTS idx_documents_group_id ON documents (group_id);
CREATE INDEX IF NOT EXISTS idx_documents_vendor_id ON documents (vendor_id);
CREATE INDEX IF NOT EXISTS idx_documents_uploaded_at ON documents (uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_file_type ON documents (file_type);

-- Communication logs (used by reminder system)
-- vendor_id and created_at indexes exist in communication_logs_migration.sql
CREATE INDEX IF NOT EXISTS idx_comm_logs_reminder_type
  ON communication_logs ((metadata->>'reminder_type'))
  WHERE metadata ? 'reminder_type';
