from __future__ import annotations

from datetime import date, datetime, time, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Task, TaskTimeInterval, User, UserPreference
from app.schemas import DayResponse, TaskResponse


def day_bounds(requested_date: date, timezone_name: str) -> tuple[datetime, datetime]:
    local_timezone = ZoneInfo(timezone_name)
    starts_at = datetime.combine(requested_date, time.min, tzinfo=local_timezone)
    ends_at = datetime.combine(requested_date.fromordinal(requested_date.toordinal() + 1), time.min, tzinfo=local_timezone)
    return starts_at.astimezone(timezone.utc), ends_at.astimezone(timezone.utc)


def interval_seconds_in_window(
    started_at: datetime,
    ended_at: datetime | None,
    window_start: datetime,
    window_end: datetime,
    now: datetime,
) -> int:
    interval_end = ended_at or now
    overlap_start = max(started_at, window_start)
    overlap_end = min(interval_end, window_end)
    return max(int((overlap_end - overlap_start).total_seconds()), 0)


def _task_response(task: Task, intervals: list[TaskTimeInterval], now: datetime) -> TaskResponse:
    duration = sum(int(((interval.ended_at or now) - interval.started_at).total_seconds()) for interval in intervals)
    return TaskResponse(id=task.id, title=task.title, status=task.status, total_duration_seconds=max(duration, 0))


def get_day_summary(db: Session, user: User, requested_date: date | None) -> DayResponse:
    preference = db.get(UserPreference, user.id)
    timezone_name = preference.timezone if preference is not None else "America/Recife"
    local_timezone = ZoneInfo(timezone_name)
    target_date = requested_date or datetime.now(local_timezone).date()
    window_start, window_end = day_bounds(target_date, timezone_name)
    now = datetime.now(timezone.utc)

    tasks = db.scalars(select(Task).where(Task.user_id == user.id).order_by(Task.created_at.desc())).all()
    intervals = db.scalars(
        select(TaskTimeInterval)
        .join(Task, Task.id == TaskTimeInterval.task_id)
        .where(Task.user_id == user.id)
        .order_by(TaskTimeInterval.started_at)
    ).all()
    intervals_by_task: dict[object, list[TaskTimeInterval]] = {}
    for interval in intervals:
        intervals_by_task.setdefault(interval.task_id, []).append(interval)

    visible_tasks: list[TaskResponse] = []
    active_task: TaskResponse | None = None
    total_duration = 0
    for task in tasks:
        task_intervals = intervals_by_task.get(task.id, [])
        duration_in_day = sum(
            interval_seconds_in_window(interval.started_at, interval.ended_at, window_start, window_end, now)
            for interval in task_intervals
        )
        total_duration += duration_in_day
        created_in_day = window_start <= task.created_at < window_end
        completed_in_day = task.completed_at is not None and window_start <= task.completed_at < window_end
        is_visible = task.status != "completed" or created_in_day or completed_in_day or duration_in_day > 0
        if not is_visible:
            continue
        response = _task_response(task, task_intervals, now)
        visible_tasks.append(response)
        if task.status == "in_progress":
            active_task = response

    return DayResponse(
        date=target_date,
        tasks=visible_tasks,
        active_task=active_task,
        total_duration_seconds=total_duration,
    )
