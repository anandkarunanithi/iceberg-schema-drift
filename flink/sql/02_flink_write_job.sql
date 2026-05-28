-- ─────────────────────────────────────────────────────────────
-- Flink: Schema v1 write job (pre-migration)
-- This job runs BEFORE the Spark ALTER TABLE.
-- It writes rows WITHOUT the region column.
-- ─────────────────────────────────────────────────────────────

USE CATALOG nessie_catalog;
USE nessie;

-- Create a datagen source to simulate streaming orders
CREATE TEMPORARY TABLE order_source (
  order_id    STRING,
  customer_id STRING,
  order_ts    TIMESTAMP(3),
  amount      DECIMAL(10,2),
  status      STRING,
  WATERMARK FOR order_ts AS order_ts - INTERVAL '5' SECOND
) WITH (
  'connector'         = 'datagen',
  'rows-per-second'   = '5',
  'fields.order_id.kind'    = 'random',
  'fields.order_id.length'  = '8',
  'fields.customer_id.kind' = 'random',
  'fields.customer_id.length' = '6',
  'fields.amount.min'       = '10',
  'fields.amount.max'       = '500',
  'fields.status.kind'      = 'random',
  'fields.status.length'    = '6'
);

-- Write to Iceberg using schema v1 (no region column)
-- ─────────────────────────────────────────────────────────────
-- FAILURE POINT: Once Spark runs 03_add_column.sql,
-- this job will start failing because the table now
-- expects region but this job does not produce it.
-- ─────────────────────────────────────────────────────────────
INSERT INTO nessie.orders (order_id, customer_id, order_ts, amount, status)
SELECT
  CONCAT('ORD-', order_id),
  CONCAT('CUST-', customer_id),
  order_ts,
  amount,
  status
FROM order_source;