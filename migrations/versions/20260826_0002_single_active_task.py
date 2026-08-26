"""enforce one active task per user

Revision ID: 20260826_0002
Revises: 20260824_0001
Create Date: 2026-08-26
"""

from alembic import op
import sqlalchemy as sa


revision = "20260826_0002"
down_revision = "20260824_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "uq_tasks_one_active_per_user",
        "tasks",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("status = 'in_progress'"),
    )


def downgrade() -> None:
    op.drop_index("uq_tasks_one_active_per_user", table_name="tasks")
