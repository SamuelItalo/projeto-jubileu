from __future__ import annotations

from datetime import date, datetime, timezone

from app.services.day import day_bounds, interval_seconds_in_window


def test_day_bounds_uses_user_timezone() -> None:
    starts_at, ends_at = day_bounds(date(2026, 8, 26), "America/Recife")

    assert starts_at == datetime(2026, 8, 26, 3, tzinfo=timezone.utc)
    assert ends_at == datetime(2026, 8, 27, 3, tzinfo=timezone.utc)


def test_interval_duration_is_limited_to_requested_day() -> None:
    starts_at, ends_at = day_bounds(date(2026, 8, 26), "America/Recife")
    duration = interval_seconds_in_window(
        datetime(2026, 8, 26, 2, 30, tzinfo=timezone.utc),
        datetime(2026, 8, 26, 3, 30, tzinfo=timezone.utc),
        starts_at,
        ends_at,
        datetime(2026, 8, 26, 12, tzinfo=timezone.utc),
    )

    assert duration == 30 * 60


def test_open_interval_uses_time_of_reading() -> None:
    starts_at, ends_at = day_bounds(date(2026, 8, 26), "America/Recife")
    duration = interval_seconds_in_window(
        datetime(2026, 8, 26, 4, tzinfo=timezone.utc),
        None,
        starts_at,
        ends_at,
        datetime(2026, 8, 26, 5, 15, tzinfo=timezone.utc),
    )

    assert duration == 75 * 60
