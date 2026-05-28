-- ─────────────────────────────────────────────────────────────
-- Step 4: Backfill historical rows
-- Only run this AFTER Flink has been updated to write region.
-- Using a placeholder here is dangerous if region is a key field.
-- ─────────────────────────────────────────────────────────────

-- Option A: Derive region from customer mapping (preferred)
-- Assumes a customer_region lookup table exists
UPDATE nessie.orders o
SET region = (
  SELECT cr.region
  FROM customer_region cr
  WHERE cr.customer_id = o.customer_id
)
WHERE o.region IS NULL;

-- Option B: Placeholder backfill (use only if derivation is not possible)
-- WARNING: This may break uniqueness assumptions on (order_id, region)
UPDATE nessie.orders
SET region = 'UNKNOWN'
WHERE region IS NULL;

-- Validate: no nulls remain
SELECT COUNT(*) AS null_region_count
FROM nessie.orders
WHERE region IS NULL;

-- Validate: check for duplicate composite keys
SELECT order_id, region, COUNT(*) AS cnt
FROM nessie.orders
GROUP BY order_id, region
HAVING COUNT(*) > 1;

-- If the above returns rows, the composite key is not safe to enforce.