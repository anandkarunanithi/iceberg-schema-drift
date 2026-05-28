-- ─────────────────────────────────────────────────────────────
-- Step 2: Insert sample data using schema v1
-- These rows have NO region — simulates pre-migration state
-- ─────────────────────────────────────────────────────────────

INSERT INTO nessie.orders VALUES
  ('ORD-001', 'CUST-A', TIMESTAMP '2024-01-01 10:00:00', 120.50, 'COMPLETED'),
  ('ORD-002', 'CUST-B', TIMESTAMP '2024-01-02 11:30:00', 89.99,  'COMPLETED'),
  ('ORD-003', 'CUST-A', TIMESTAMP '2024-01-03 09:15:00', 250.00, 'PENDING'),
  ('ORD-004', 'CUST-C', TIMESTAMP '2024-01-04 14:00:00', 45.00,  'COMPLETED'),
  ('ORD-005', 'CUST-B', TIMESTAMP '2024-01-05 16:45:00', 310.75, 'CANCELLED');

-- Verify row count
SELECT COUNT(*) AS total_rows FROM nessie.orders;

-- Inspect snapshot history
SELECT * FROM nessie.orders.snapshots;