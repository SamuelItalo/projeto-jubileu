"""Initial Jubilee schema.

Revision ID: 20260824_0001
Revises:
Create Date: 2026-08-24
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20260824_0001"
down_revision = None
branch_labels = None
depends_on = None


def uuid_column() -> sa.Column:
    return sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False)


def upgrade() -> None:
    op.create_table(
        "users", uuid_column(), sa.Column("username", sa.String(100), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("username"),
    )
    op.create_table(
        "sessions", uuid_column(), sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token_hash", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)), sa.UniqueConstraint("token_hash"),
    )
    op.create_index("ix_sessions_user_revoked", "sessions", ["user_id", "revoked_at"])
    op.create_table(
        "user_preferences", sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("timezone", sa.String(64), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_table(
        "tasks", uuid_column(), sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(300), nullable=False), sa.Column("description", sa.Text()), sa.Column("category", sa.String(100)),
        sa.Column("priority", sa.String(30)), sa.Column("mood", sa.String(100)), sa.Column("status", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True)), sa.Column("ended_at", sa.DateTime(timezone=True)), sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint("status IN ('pending', 'in_progress', 'paused', 'completed')", name="ck_tasks_status"),
    )
    op.create_index("ix_tasks_user_status", "tasks", ["user_id", "status"])
    op.create_table(
        "task_time_intervals", uuid_column(), sa.Column("task_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False), sa.Column("ended_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("ended_at IS NULL OR ended_at >= started_at", name="ck_interval_end_after_start"),
    )
    op.create_index("ix_intervals_task_started", "task_time_intervals", ["task_id", "started_at"])
    op.create_index("uq_active_interval_per_task", "task_time_intervals", ["task_id"], unique=True, postgresql_where=sa.text("ended_at IS NULL"))
    op.create_table(
        "task_notes", uuid_column(), sa.Column("task_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("content", sa.Text(), nullable=False), sa.Column("source", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_notes_task_created", "task_notes", ["task_id", "created_at"])
    op.create_table(
        "voice_requests", sa.Column("request_id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False), sa.Column("timezone", sa.String(64), nullable=False),
        sa.Column("source", sa.String(20), nullable=False), sa.Column("transcript", sa.Text(), nullable=False), sa.Column("status", sa.String(30), nullable=False),
        sa.Column("response_json", postgresql.JSONB()), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_voice_requests_user_created", "voice_requests", ["user_id", "created_at"])
    op.create_table(
        "pending_action_groups", uuid_column(), sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("origin_request_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("voice_requests.request_id"), nullable=False),
        sa.Column("status", sa.String(20), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False), sa.Column("resolved_at", sa.DateTime(timezone=True)),
        sa.Column("resolution_request_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("voice_requests.request_id")),
        sa.CheckConstraint("status IN ('pending', 'resolved', 'expired')", name="ck_pending_groups_status"),
    )
    op.create_index("ix_pending_groups_user_status_expiry", "pending_action_groups", ["user_id", "status", "expires_at"])
    op.create_table(
        "pending_actions", uuid_column(), sa.Column("group_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("pending_action_groups.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("origin_request_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("voice_requests.request_id"), nullable=False),
        sa.Column("action_json", postgresql.JSONB(), nullable=False), sa.Column("status", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False), sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True)), sa.Column("resolution_request_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("voice_requests.request_id")),
        sa.CheckConstraint("status IN ('pending', 'confirmed', 'cancelled', 'expired')", name="ck_pending_actions_status"),
    )
    op.create_index("ix_pending_actions_group_status", "pending_actions", ["group_id", "status"])
    op.create_index("ix_pending_actions_user_status_expiry", "pending_actions", ["user_id", "status", "expires_at"])


def downgrade() -> None:
    for table in ("pending_actions", "pending_action_groups", "voice_requests", "task_notes", "task_time_intervals", "tasks", "user_preferences", "sessions", "users"):
        op.drop_table(table)

