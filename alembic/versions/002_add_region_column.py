"""002_add_region_column

Revision ID: 002
Revises: 001
Create Date: 2024-02-01 00:00:00

IMPORTANT: This migration adds the region column to the
relational tracking table. The actual Iceberg DDL must be
applied separately via Spark SQL (03_add_column.sql).

Alembic cannot directly modify Iceberg table properties
or identifier fields. This migration is a tracking record
only — it does NOT update the Iceberg catalog.

Coordination required:
  1. Apply this Alembic migration (relational tracking)
  2. Run Spark SQL 03_add_column.sql (Iceberg metadata)
  3. Redeploy Flink job with schema v2
  4. Run Spark SQL 04_backfill_region.sql
  5. Validate with Spark SQL 05_verify_schema.sql
"""

from alembic import op
import sqlalchemy as sa

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add region column to relational tracking table
    op.add_column(
        "orders",
        sa.Column("region", sa.String(64), nullable=True)
    )

    # NOTE: Primary key constraint update is intentionally
    # deferred. In Iceberg, key semantics are managed at the
    # engine level, not enforced here. Updating the PK here
    # would only affect the relational tracking table, not
    # the actual Iceberg table behavior.

    # Add index for region-based queries
    op.create_index(
        "ix_orders_region",
        "orders",
        ["region"]
    )


def downgrade() -> None:
    op.drop_index("ix_orders_region", table_name="orders")
    op.drop_column("orders", "region")