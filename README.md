# Iceberg Schema Drift Demo

## Problem Statement
This project demonstrates schema drift in a multi-engine Iceberg environment.

A streaming Flink writer continuously inserts rows into an Iceberg table while Spark evolves table metadata by adding a new column named `region`. When the table schema changes but the active writer still uses the old projection, writes become unstable and can fail. This demo shows how to reproduce that failure and recover safely through a phased migration flow.

## What You Will Learn
1. How schema drift appears when Spark and Flink are not migrated in lockstep.
2. Why a nullable schema widening step is low risk, but writer and backfill phases are operationally sensitive.
3. How to validate migration safety with null checks, uniqueness checks, and runtime monitoring.
4. How Alembic migration tracking relates to, but does not replace, Iceberg schema operations.

## Architecture

### Components
1. **MinIO**
   - S3-compatible object storage for Iceberg data and Flink checkpoints.
2. **Nessie**
   - Iceberg catalog and metadata timeline.
3. **Spark**
   - Executes table DDL, schema evolution, backfill, and verification queries.
4. **Flink**
   - Runs streaming writers before and after migration.
5. **PostgreSQL + Alembic**
   - Relational migration tracking and audit context.

### Service Endpoints
1. MinIO API: `http://localhost:9000`
2. MinIO Console: `http://localhost:9001`
3. Nessie API: `http://localhost:19120/api/v1`
4. PostgreSQL: `localhost:5432`
5. Spark UI: `http://localhost:4040`
6. Flink UI: `http://localhost:8081`

## Repository Layout
- `docker-compose.yml`: Local stack orchestration for all services.
- `alembic/versions/001_create_orders_table.py`: Initial relational tracking migration.
- `alembic/versions/002_add_region_column.py`: Relational tracking for `region` column addition.
- `spark/sql/01_create_table.sql`: Creates Iceberg `orders` table.
- `spark/sql/02_insert_sample_data.sql`: Inserts baseline data.
- `spark/sql/03_add_column.sql`: Adds `region` column and triggers drift conditions.
- `spark/sql/04_backfill_region.sql`: Backfills historical `region` values and checks quality.
- `spark/sql/05_verify_schema.sql`: Final migration verification.
- `flink/sql/01_flink_create_table.sql`: Registers Nessie-backed Iceberg catalog in Flink.
- `flink/sql/02_flink_write_job.sql`: Pre-migration Flink writer (no `region`).
- `flink/sql/03_flink_post_migration_job.sql`: Post-migration Flink writer (with `region`).

## Prerequisites
1. Docker and Docker Compose.
2. At least 8 GB RAM available to Docker.
3. Local ports 9000, 9001, 19120, 5432, 4040, 8081 available.

## Bootstrap Checklist
Before running, verify the stack has all required mounted configuration and dependency assets expected by compose. The compose file mounts local Spark and Flink config plus additional jar libraries; missing assets can prevent Spark or Flink from starting correctly.

## Start the Stack
From this folder (`iceberg-schema-drift`):

```bash
docker compose up
```

In another terminal, verify containers are running:

```bash
docker ps
```

Optional cleanup:

```bash
docker compose down -v
```

Expected startup behavior:
1. MinIO starts and creates `warehouse` and `checkpoints` buckets.
2. Nessie starts with in-memory catalog state.
3. PostgreSQL starts and Alembic applies migrations.
4. Spark and Flink become available for SQL execution.

## Quick Start: Reproduce Drift in Minutes

### Step 1: Create table and seed data with Spark
```bash
docker exec -it demo-spark ./bin/spark-sql \
  --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \
  -f /workspace/sql/01_create_table.sql

docker exec -it demo-spark ./bin/spark-sql \
  --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \
  -f /workspace/sql/02_insert_sample_data.sql

docker exec -it demo-spark ./bin/spark-sql \
  --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \
  -e "SELECT COUNT(*) FROM nessie.orders;"
```

### Step 2: Start Flink catalog and v1 writer
```bash
docker exec -it demo-flink-jobmanager ./bin/sql-client.sh \
  -f /workspace/sql/01_flink_create_table.sql

docker exec -it demo-flink-jobmanager ./bin/sql-client.sh \
  -f /workspace/sql/02_flink_write_job.sql
```

Expected result:
1. Flink job runs continuously.
2. Row count in `nessie.orders` increases over time.

### Step 3: Trigger schema drift
```bash
docker exec -it demo-spark ./bin/spark-sql \
  --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \
  -f /workspace/sql/03_add_column.sql
```

Expected result:
1. Table schema now includes `region`.
2. Flink v1 writer may begin failing or restarting due to schema mismatch.

### Step 4: Observe failure
1. Open Flink UI at `http://localhost:8081`.
2. Inspect job status, restarts, and task exceptions.
3. Optionally inspect JobManager logs:

```bash
docker logs demo-flink-jobmanager | tail -100
```

## Full Migration Runbook (Failure to Recovery)

### Phase 1: Schema Widening
1. Ensure Alembic migration tracking is current (auto-run via compose).
2. Apply Iceberg schema widening in Spark:

```bash
docker exec -it demo-spark ./bin/spark-sql \
  --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \
  -f /workspace/sql/03_add_column.sql
```

Validation:
1. `region` appears in `DESCRIBE` output.
2. Snapshot history shows a schema evolution event.

### Phase 2: Writer Update
1. Stop old Flink v1 writer.
2. Deploy updated writer:

```bash
docker exec -it demo-flink-jobmanager ./bin/sql-client.sh \
  -f /workspace/sql/03_flink_post_migration_job.sql
```

Validation:
1. New rows include `region` values.
2. No ongoing writer schema errors.

### Phase 3: Backfill Historical Data
Run:

```bash
docker exec -it demo-spark ./bin/spark-sql \
  --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \
  -f /workspace/sql/04_backfill_region.sql
```

Validation:
1. `region` null count reaches zero.
2. No duplicate `(order_id, region)` pairs.

### Phase 4: Final Verification
Run:

```bash
docker exec -it demo-spark ./bin/spark-sql \
  --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \
  -f /workspace/sql/05_verify_schema.sql
```

Validation:
1. Schema is as expected.
2. Snapshot timeline is coherent.
3. Mixed historical and new rows are queryable.

## Validation Checklist
1. Flink post-migration writer is running without repeated failures.
2. `region` null count is zero.
3. Composite uniqueness checks return no duplicates.
4. Grouped `region` counts return non-empty results.

## Troubleshooting

### Services Do Not Become Healthy
1. Check container logs:

```bash
docker logs demo-minio
docker logs demo-nessie
docker logs demo-postgres
docker logs demo-spark
docker logs demo-flink-jobmanager
```

2. Confirm required local mounts and dependency jars exist for Spark and Flink startup.

### Spark Cannot Query Nessie Tables
1. Verify Spark command includes the catalog configuration flag.
2. Verify Nessie endpoint accessibility from containers.
3. Check MinIO credentials and bucket creation.

### Flink Job Fails After Schema Change
1. This is expected for the v1 writer after `region` is added.
2. Stop v1 writer and submit v2 writer script.
3. Re-check task exceptions and restart counters in Flink UI.

### Backfill Issues
1. Preferred backfill path expects a `customer_region` lookup source.
2. If using fallback placeholder values, validate uniqueness assumptions carefully before proceeding.

## Known Limitations and Assumptions
1. The compose stack expects local config and jar mounts that are not fully provisioned in this repository snapshot:
   - `spark/conf/spark-defaults.conf`
   - `flink/conf/flink-conf.yaml`
   - `jars/`
2. Preferred backfill depends on a lookup table (`customer_region`) not created by provided scripts.
3. Identifier-field update semantics are described in migration notes but not fully scripted as a dedicated SQL step.
4. `../migration-notes/FAILURE_REPRODUCTION.md` appears incomplete; this README provides a corrected runnable flow.

## Suggested Next Improvements
1. Add a bootstrap script that validates required mounts and jars before startup.
2. Add a dedicated script for identifier-field metadata updates with engine compatibility notes.
3. Expand failure notes with real error snippets and expected remediation signals.

## License
See `LICENSE`.
