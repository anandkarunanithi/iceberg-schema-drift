-- ─────────────────────────────────────────────────────────────
-- Flink: Register Iceberg catalog backed by Nessie
-- Run this in Flink SQL CLI or submit as a job
-- ─────────────────────────────────────────────────────────────

CREATE CATALOG nessie_catalog WITH (
  'type'                    = 'iceberg',
  'catalog-impl'            = 'org.apache.iceberg.nessie.NessieCatalog',
  'uri'                     = 'http://nessie:19120/api/v1',
  'ref'                     = 'main',
  'warehouse'               = 's3://warehouse/',
  's3.endpoint'             = 'http://minio:9000',
  's3.path-style-access'    = 'true',
  's3.access-key-id'        = 'minioadmin',
  's3.secret-access-key'    = 'minioadmin123'
);

USE CATALOG nessie_catalog;
USE nessie;

-- ─────────────────────────────────────────────────────────────
-- Schema v1: Flink view of the table BEFORE migration
-- This is what Flink uses when the job starts
-- ─────────────────────────────────────────────────────────────
DESCRIBE orders;