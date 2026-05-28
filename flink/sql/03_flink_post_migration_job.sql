-- ─────────────────────────────────────────────────────────────
-- Flink: Schema v2 write job (post-migration)
-- This job runs AFTER:
--   1. Spark has added the region column
--   2. Historical data has been backfilled
--   3. This job has been redeployed with the new schema
-- ─────────────────────────────────────────────────────────────

USE CATALOG nessie_catalog;
USE nessie;

-- Updated source now includes region
CREATE TEMPORARY TABLE order_source_v2 (
  order_id    STRING,
  customer_id STRING,
  order_ts    TIMESTAMP(3),
  amount      DECIMAL(10,2),
  status      STRING,
  region      STRING,
  WATERMARK FOR order_ts AS order_ts - INTERVAL '5' SECOND
) WITH (
  'connector'               = 'datagen',
  'rows-per-second'         = '5',
  'fields.order_id.kind'    = 'random',
  'fields.order_id.length'  = '8',
  'fields.customer_id.kind' = 'random',
  'fields.customer_id.length' = '6',
  'fields.amount.min'       = '10',
  'fields.amount.max'       = '500',
  'fields.status.kind'      = 'random',
  'fields.status.length'    = '6',
  'fields.region.kind'      = 'random',
  'fields.region.length'    = '4'
);

-- Write to Iceberg using schema v2 (with region)
-- This job is safe to run after full migration validation
INSERT INTO nessie.orders (order_id, customer_id, order_ts, amount, status, region)
SELECT
  CONCAT('ORD-', order_id),
  CONCAT('CUST-', customer_id),
  order_ts,
  amount,
  status,
  UPPER(region)
FROM order_source_v2;

-- ─────────────────────────────────────────────────────────────
-- Verify writes are landing correctly
-- ─────────────────────────────────────────────────────────────
SELECT region, COUNT(*) AS row_count
FROM nessie.orders
GROUP BY region
ORDER BY row_count DESC;