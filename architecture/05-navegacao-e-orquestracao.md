# POP 05 — Navegação e orquestração

## Objetivo

Definir como o backend escolhe, de forma previsível, entre autenticar, validar, interpretar, pedir esclarecimento, criar confirmação pendente e aplicar uma mudança. A navegação não contém regra de negócio nova: ela apenas aplica os POPs 01 a 04 na ordem correta.

## Rotas de decisão

| Entrada | Rota | Resultado |
| --- | --- | --- |
| `POST /auth/login` | Validar acesso local e criar/reutilizar sessão. | Token opaco de sessão ou `401`. |
| `GET /auth/session` | Validar token ativo. | Sessão válida ou `401`. |
| `POST /auth/logout` | Revogar somente o token atual. | Confirmação sem apagar dados. |
| `GET /day` | Validar token e consultar tarefas no fuso solicitado. | Visão diária somente de leitura. |
| `POST /commands` sem `confirmation_context` | Validar e interpretar a fala. | Esclarecimento, confirmação pendente ou ação concluída. |
| `POST /commands` com `confirmation_context` | Validar grupo/item pendente e classificar a fala exclusivamente como confirmação, cancelamento ou ambiguidade. | Ações originais aplicadas, descartadas ou `needs_clarification`. |

## Fluxo de `POST /commands`

1. Validar token de sessão, `VoiceCommandRequest` e propriedade do contexto de confirmação, quando houver.
2. Consultar `voice_requests` pelo `request_id`: devolver a resposta persistida se já concluído; devolver `409 request_in_progress` se ainda estiver processando.
3. Registrar a solicitação como `processing` em transação.
4. Se houver `confirmation_context`, verificar expiração, estado do grupo e do item. Normalizar a nova transcrição e classificá-la deterministicamente como confirmação explícita, cancelamento explícito ou ambiguidade. A IA não é chamada nessa rota.
5. Sem contexto de confirmação, enviar somente a transcrição e o contexto mínimo ao adaptador de IA e validar o `InterpretedCommand` retornado.
6. Resolver referências de tarefa. Alvo ausente, ambíguo ou semelhante produz `needs_clarification`, sem alterar tarefas.
7. Para `create_task`, gerar `pending_action_groups` e `pending_actions`, com validade de cinco minutos, e devolver `awaiting_confirmation`.
8. Para `start_task`, `pause_task`, `resume_task`, `complete_task` e `add_note`, exigir comando explícito e alvo único; aplicar a transição ou nota diretamente, pois a própria fala explícita é a autorização exigida pelo MVP.
9. Gravar a resposta final no mesmo limite transacional da alteração de tarefas ou da resolução de pendências. Retentativas posteriores devolvem essa resposta, sem repetir efeitos.

## Confirmações explícitas

- O classificador aceita somente expressões inequívocas após normalização (minúsculas, sem pontuação e sem acentos): `confirmo`, `sim confirmar`, `pode criar`, `confirmar` e `cancelo`, `cancelar`, `não`.
- Expressões fora da lista devolvem `needs_clarification`; não chamam a IA e não alteram a ação original.
- Um `group_id` sem `action_id` resolve todas as ações ainda pendentes do grupo. Com `action_id`, resolve somente o item indicado.
- O grupo permanece `pending` enquanto tiver itens pendentes; é marcado `resolved` quando todos os seus itens forem confirmados ou cancelados. A expiração marca somente os itens ainda pendentes como `expired` e encerra o grupo.

## Ordem de aplicação em grupo

Quando confirmar um grupo, o backend valida todas as ações antes de começar e as aplica numa única transação. Se uma delas ficar inválida por mudança de estado, a transação é revertida e a resposta é `invalid_state`; nenhum item do grupo é aplicado parcialmente.

## Casos de borda

| Situação | Decisão |
| --- | --- |
| Contexto de outro usuário ou sessão | `403 forbidden`. |
| Grupo/item inexistente | `404 not_found`. |
| Contexto expirado | `410 pending_action_expired`. |
| Confirmação ambígua | `422 needs_clarification`, mantendo a pendência válida até expirar. |
| IA indisponível ou retorno inválido | `502 interpretation_unavailable`, sem pendência nem mudança de tarefa. |
| Repetição do mesmo `request_id` | Reutilizar a resposta persistida; nunca reaplicar a ação. |

## Entrega da Camada 2

Esta navegação conecta os POPs técnicos a implementações determinísticas do backend. A próxima etapa é construir a Camada 3: projeto FastAPI, modelos, migrações, serviços de persistência, adaptador de IA e testes dos fluxos acima.
