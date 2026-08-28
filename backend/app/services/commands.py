from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import PendingAction, PendingActionGroup, Task, TaskNote, TaskTimeInterval, User, VoiceRequest
from app.schemas import AssistantResponse, ConfirmationContext, TaskResponse, VoiceCommandRequest
from app.services.interpreter import ParsedAction, confirmation_decision, normalize, parse_deterministic
from app.services.ollama import parse_with_ollama


def _task_response(db: Session, task: Task) -> TaskResponse:
    now = datetime.now(timezone.utc)
    intervals = db.scalars(select(TaskTimeInterval).where(TaskTimeInterval.task_id == task.id)).all()
    duration = sum(int(((interval.ended_at or now) - interval.started_at).total_seconds()) for interval in intervals)
    return TaskResponse(id=task.id, title=task.title, status=task.status, total_duration_seconds=max(duration, 0))


def _store_response(db: Session, request: VoiceRequest, response: AssistantResponse) -> AssistantResponse:
    request.status = response.status
    request.response_json = response.model_dump(mode="json")
    request.completed_at = datetime.now(timezone.utc)
    db.commit()
    return response


def _from_stored_response(request: VoiceRequest) -> AssistantResponse:
    return AssistantResponse.model_validate(request.response_json)


def _find_task(db: Session, user: User, title: str) -> Task | AssistantResponse:
    normalized_title = normalize(title)
    matches = [
        task
        for task in db.scalars(select(Task).where(Task.user_id == user.id)).all()
        if normalize(task.title) == normalized_title
    ]
    if not matches:
        return AssistantResponse(
            request_id=UUID(int=0),
            status="needs_clarification",
            message="Não encontrei essa tarefa.",
            clarification_question=f"Qual tarefa você quis dizer? Não encontrei ‘{title}’.",
        )
    if len(matches) > 1:
        return AssistantResponse(
            request_id=UUID(int=0),
            status="needs_clarification",
            message="Encontrei mais de uma tarefa com esse nome.",
            clarification_question="Diga um título mais específico para identificar a tarefa.",
        )
    return matches[0]


def _apply_action(db: Session, user: User, action: ParsedAction) -> Task | AssistantResponse:
    found = _find_task(db, user, action.title)
    if isinstance(found, AssistantResponse):
        return found
    task = found
    now = datetime.now(timezone.utc)

    if action.type == "start_task":
        if task.status != "pending":
            raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})
        active_task = db.scalar(
            select(Task).where(Task.user_id == user.id, Task.status == "in_progress", Task.id != task.id)
        )
        if active_task is not None:
            raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})
        task.status = "in_progress"
        task.started_at = task.started_at or now
        db.add(TaskTimeInterval(task_id=task.id, started_at=now))
    elif action.type == "pause_task":
        if task.status != "in_progress":
            raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})
        interval = db.scalar(select(TaskTimeInterval).where(TaskTimeInterval.task_id == task.id, TaskTimeInterval.ended_at.is_(None)))
        if interval is None:
            raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})
        interval.ended_at = now
        task.status = "paused"
    elif action.type == "resume_task":
        if task.status != "paused":
            raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})
        active_task = db.scalar(
            select(Task).where(Task.user_id == user.id, Task.status == "in_progress", Task.id != task.id)
        )
        if active_task is not None:
            raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})
        task.status = "in_progress"
        db.add(TaskTimeInterval(task_id=task.id, started_at=now))
    elif action.type == "complete_task":
        if task.status == "completed":
            raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})
        if task.status == "in_progress":
            interval = db.scalar(select(TaskTimeInterval).where(TaskTimeInterval.task_id == task.id, TaskTimeInterval.ended_at.is_(None)))
            if interval is None:
                raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})
            interval.ended_at = now
        task.status = "completed"
        task.ended_at = now
        task.completed_at = now
    elif action.type == "add_note":
        db.add(TaskNote(task_id=task.id, content=action.note or "", source="voice"))
    else:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail={"code": "invalid_request"})
    db.flush()
    return task


def _create_pending_actions(db: Session, user: User, request: VoiceRequest, actions: list[ParsedAction]) -> AssistantResponse:
    now = datetime.now(timezone.utc)
    group = PendingActionGroup(
        user_id=user.id,
        origin_request_id=request.request_id,
        expires_at=now + timedelta(minutes=5),
    )
    db.add(group)
    db.flush()
    pending = [
        PendingAction(
            group_id=group.id,
            user_id=user.id,
            origin_request_id=request.request_id,
            action_json={"type": action.type, "title": action.title, "note": action.note},
            expires_at=group.expires_at,
        )
        for action in actions
    ]
    db.add_all(pending)
    db.flush()
    return AssistantResponse(
        request_id=request.request_id,
        status="awaiting_confirmation",
        message="Entendi a criação da tarefa. Confirma?",
        tasks=[TaskResponse(id=item.id, title=actions[index].title, status="pending", total_duration_seconds=0) for index, item in enumerate(pending)],
        requires_confirmation=True,
        confirmation_context=ConfirmationContext(group_id=group.id),
    )


def _resolve_confirmation(db: Session, user: User, request: VoiceRequest, payload: VoiceCommandRequest) -> AssistantResponse:
    context = payload.confirmation_context
    assert context is not None
    group = db.get(PendingActionGroup, context.group_id)
    if group is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail={"code": "not_found"})
    if group.user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail={"code": "forbidden"})
    now = datetime.now(timezone.utc)
    actions = db.scalars(select(PendingAction).where(PendingAction.group_id == group.id)).all()
    selected = [action for action in actions if context.action_id is None or action.id == context.action_id]
    if not selected:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail={"code": "not_found"})
    if group.expires_at <= now:
        for action in actions:
            if action.status == "pending":
                action.status = "expired"
        group.status = "expired"
        db.flush()
        raise HTTPException(status.HTTP_410_GONE, detail={"code": "pending_action_expired"})
    if any(action.status != "pending" for action in selected):
        raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})

    decision = confirmation_decision(payload.transcript)
    if decision is None:
        return AssistantResponse(
            request_id=request.request_id,
            status="needs_clarification",
            message="Não entendi se você confirma ou cancela.",
            clarification_question="Diga ‘confirmo’ ou ‘cancelo’.",
            requires_confirmation=True,
            confirmation_context=context,
        )

    if decision == "cancel":
        for action in selected:
            action.status = "cancelled"
            action.resolved_at = now
            action.resolution_request_id = request.request_id
        if not any(action.status == "pending" for action in actions):
            group.status = "resolved"
            group.resolved_at = now
            group.resolution_request_id = request.request_id
        return AssistantResponse(request_id=request.request_id, status="rejected", message="Ação cancelada.")

    created_tasks: list[Task] = []
    for action in selected:
        candidate = action.action_json
        if candidate["type"] != "create_task":
            raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "invalid_state"})
        task = Task(user_id=user.id, title=candidate["title"], status="pending")
        db.add(task)
        db.flush()
        created_tasks.append(task)
        action.status = "confirmed"
        action.resolved_at = now
        action.resolution_request_id = request.request_id
    if not any(action.status == "pending" for action in actions):
        group.status = "resolved"
        group.resolved_at = now
        group.resolution_request_id = request.request_id
    return AssistantResponse(
        request_id=request.request_id,
        status="completed",
        message="Tarefa criada com sucesso.",
        tasks=[_task_response(db, task) for task in created_tasks],
    )


def process_command(db: Session, user: User, payload: VoiceCommandRequest) -> AssistantResponse:
    existing = db.get(VoiceRequest, payload.request_id)
    if existing is not None:
        if existing.user_id != user.id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, detail={"code": "forbidden"})
        if existing.response_json is not None:
            return _from_stored_response(existing)
        raise HTTPException(status.HTTP_409_CONFLICT, detail={"code": "request_in_progress"})

    request = VoiceRequest(
        request_id=payload.request_id,
        user_id=user.id,
        occurred_at=payload.occurred_at,
        timezone=payload.timezone,
        source=payload.source,
        transcript=payload.transcript,
        status="processing",
    )
    db.add(request)
    db.flush()

    if payload.confirmation_context is not None:
        response = _resolve_confirmation(db, user, request, payload)
        return _store_response(db, request, response)

    settings = get_settings()
    parsed = parse_deterministic(payload.transcript)
    if settings.command_interpreter == "ollama_first" and payload.source == "voice":
        llm_parsed = parse_with_ollama(payload.transcript, settings)
        if llm_parsed is not None:
            parsed = llm_parsed
    elif parsed.clarification_question and settings.command_interpreter == "hybrid_ollama":
        llm_parsed = parse_with_ollama(payload.transcript, settings)
        if llm_parsed is not None:
            parsed = llm_parsed
    if parsed.clarification_question:
        response = AssistantResponse(
            request_id=payload.request_id,
            status="needs_clarification",
            message="Preciso de um comando mais claro.",
            clarification_question=parsed.clarification_question,
        )
        return _store_response(db, request, response)

    create_actions = [action for action in parsed.actions if action.type == "create_task"]
    if create_actions:
        if len(create_actions) != len(parsed.actions):
            response = AssistantResponse(
                request_id=payload.request_id,
                status="needs_clarification",
                message="Não misture criação com outros comandos na mesma fala.",
                clarification_question="Confirme a criação primeiro e envie os demais comandos em outra fala.",
            )
            return _store_response(db, request, response)
        return _store_response(db, request, _create_pending_actions(db, user, request, create_actions))

    affected: list[Task] = []
    for action in parsed.actions:
        result = _apply_action(db, user, action)
        if isinstance(result, AssistantResponse):
            result.request_id = payload.request_id
            return _store_response(db, request, result)
        affected.append(result)
    response = AssistantResponse(
        request_id=payload.request_id,
        status="completed",
        message="Comando aplicado com sucesso.",
        tasks=[_task_response(db, task) for task in affected],
    )
    return _store_response(db, request, response)
