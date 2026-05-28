-- ─────────────────────────────────────────────────────────────
-- Step 5: Final verification before key metadata update
-- Run this only after all writers are producing region
-- and historical data has been backfilled and validated
-- ─────────────────────────────────────────────────────────────

-- Full schema inspection
DESCRIBE EXTENDED nessie.orders;

-- Snapshot timeline
SELECT
  snapshot_id,
  committed_at,
  operation,
  summary['added-records']   AS added_records,
  summary['changed-partition-count'] AS changed_partitions
FROM nessie.orders.snapshots
ORDER BY committed_at ASC;

-- Sample rows across both schema versions
SELECT * FROM nessie.orders LIMIT 20;

-- Null check
SELECT
  SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS null_regions,
  COUNT(*) AS total_rows
FROM nessie.orders;

-- Composite key uniqueness check
SELECT order_id, region, COUNT(*) AS cnt
FROM nessie.orders
GROUP BY order_id, region
HAVING COUNT(*) > 1
ORDER BY cnt DESC;