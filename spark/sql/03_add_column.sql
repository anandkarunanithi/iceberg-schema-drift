-- ─────────────────────────────────────────────────────────────
-- Step 3: Add the region column
-- This is the DDL that Spark applies to Iceberg metadata.
-- Flink is still running at this point — drift begins here.
-- ─────────────────────────────────────────────────────────────

-- Add the column (nullable initially — safe schema evolution)
ALTER TABLE nessie.orders
ADD COLUMNS (region STRING);

-- Confirm the new schema
DESCRIBE nessie.orders;

-- Check snapshot history — a new snapshot is created
SELECT snapshot_id, committed_at, operation, summary
FROM nessie.orders.snapshots
ORDER BY committed_at DESC;

-- ─────────────────────────────────────────────────────────────
-- IMPORTANT: At this point, Flink is still writing schema v1.
-- The table metadata is now v2. Drift is active.
-- Do NOT update key semantics yet.
-- ─────────────────────────────────────────────────────────────