"""001_create_orders_table

Revision ID: 001
Revises:
Create Date: 2024-01-01 00:00:00

NOTE: This migration tracks the relational representation
of the orders table. The Iceberg table itself is managed
separately via Spark SQL. Alembic here acts as a migration
audit trail, not the Iceberg DDL authority.
"""

from alembic import op
import sqlalchemy as sa

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "orders",
        sa.Column("order_id",    sa.String(64),    nullable=False),
        sa.Column("customer_id", sa.String(64),    nullable=False),
        sa.Column("order_ts",    sa.TIMESTAMP(),   nullable=False),
        sa.Column("amount",      sa.Numeric(10,2), nullable=False),
        sa.Column("status",      sa.String(32),    nullable=True),
        sa.PrimaryKeyConstraint("order_id"),
    )

    op.create_index(
        "ix_orders_customer_id",
        "orders",
        ["customer_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_orders_customer_id", table_name="orders")
    op.drop_table("orders")