-- ─────────────────────────────────────────────────────────────
-- Step 1: Create the initial orders table
-- Schema v1: order_id is the sole identity field
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS nessie.orders (
  order_id     STRING        NOT NULL,
  customer_id  STRING        NOT NULL,
  order_ts     TIMESTAMP     NOT NULL,
  amount       DECIMAL(10,2) NOT NULL,
  status       STRING
)
USING iceberg
TBLPROPERTIES (
  'write.format.default'          = 'parquet',
  'write.parquet.compression-codec' = 'snappy',
  'history.expire.max-snapshot-age-ms' = '604800000',
  'write.metadata.delete-after-commit.enabled' = 'true',
  'write.metadata.previous-versions-max' = '10'
);

-- Verify creation
DESCRIBE EXTENDED nessie.orders;