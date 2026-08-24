# POP 03 — API, persistência e fronteiras

## Objetivo

Definir responsabilidades e limites de confiança para que Flutter, FastAPI, IA e PostgreSQL não contornem as regras de negócio.

## Responsabilidades

| Componente | Responsabilidade | Não pode fazer |
| --- | --- | --- |
| Flutter | Capturar interação, enviar solicitação, exibir resposta e enviar confirmação explícita. | Decidir estado, calcular duração oficial ou acessar segredos. |
| FastAPI | Validar contratos, aplicar POPs, orquestrar IA, persistir e responder. | Confiar cegamente em texto/JSON da IA ou executar ação sem regra/confirmação. |
| IA em nuvem | Interpretar somente o texto transcrito e devolver estrutura candidata. | Acessar banco, receber chave no cliente ou executar mudanças. |
| PostgreSQL | Fonte de verdade para tarefas, intervalos, notas, preferências, transcrições e resultados de interpretação. | Substituir as validações da API. |

## Interfaces HTTP

Todos os caminhos usam o prefixo `/v1` e JSON. Com exceção de `POST /auth/login`, exigem `Authorization: Bearer <token-da-sessao>`. O token é opaco, gerado pelo backend e guardado pelo Flutter no armazenamento seguro do dispositivo.

| Método e caminho | Corpo / parâmetros | Resultado |
| --- | --- | --- |
| `POST /auth/login` | `username`, `password` | Valida Samuel e cria ou reutiliza sessão; devolve token opaco e dados mínimos da sessão. |
| `GET /auth/session` | nenhum | Confirma que a sessão persistida continua válida. |
| `POST /auth/logout` | nenhum | Revoga somente a sessão atual; não remove dados. |
| `POST /commands` | `VoiceCommandRequest` | Processa transcrição, cria ação pendente quando exigido e devolve `AssistantResponse`. |
| `GET /day?date=YYYY-MM-DD` | data opcional no fuso do usuário | Devolve tarefas, tarefa ativa e duração corrente do dia; não altera dados. |

Uma confirmação ou cancelamento por voz também usa `POST /commands`: o Flutter envia nova transcrição e o `confirmation_context` recebido previamente, contendo `group_id` e, opcionalmente, `action_id`. Não há endpoint que confirme uma ação sem fala explícita.

## Modelo relacional

| Tabela | Campos essenciais | Regras e índices |
| --- | --- | --- |
| `users` | `id UUID PK`, `username`, `password_hash`, `created_at`, `updated_at` | `username` único; somente Samuel no MVP. |
| `sessions` | `id UUID PK`, `user_id FK`, `token_hash`, `created_at`, `last_seen_at`, `revoked_at` | `token_hash` único; índice em `user_id, revoked_at`; token puro nunca é armazenado. |
| `user_preferences` | `user_id PK/FK`, `timezone`, `updated_at` | Cria preferência padrão junto do usuário; a confirmação de criação não é configurável no MVP. |
| `tasks` | `id UUID PK`, `user_id FK`, `title`, `description`, `category`, `priority`, `mood`, `status`, `created_at`, `started_at`, `ended_at`, `completed_at` | Índice em `user_id, status`; `status` limitado aos quatro estados do POP 02. |
| `task_time_intervals` | `id UUID PK`, `task_id FK`, `started_at`, `ended_at`, `created_at` | Índice em `task_id, started_at`; `ended_at` nulo somente no intervalo ativo; unicidade parcial de um intervalo ativo por tarefa. |
| `task_notes` | `id UUID PK`, `task_id FK`, `content`, `source`, `created_at` | Índice em `task_id, created_at`. |
| `voice_requests` | `request_id UUID PK`, `user_id FK`, `occurred_at`, `timezone`, `source`, `transcript`, `status`, `response_json`, `created_at`, `completed_at` | Chave primária em `request_id`; índice em `user_id, created_at`; guarda resposta para retentativa idempotente. |
| `pending_action_groups` | `id UUID PK`, `user_id FK`, `origin_request_id FK`, `status`, `created_at`, `expires_at`, `resolved_at`, `resolution_request_id` | Índice em `user_id, status, expires_at`; agrupa ações de uma mesma fala e expira em cinco minutos. |
| `pending_actions` | `id UUID PK`, `group_id FK`, `user_id FK`, `origin_request_id FK`, `action_json`, `status`, `created_at`, `expires_at`, `resolved_at`, `resolution_request_id` | Índice em `group_id, status` e em `user_id, status, expires_at`; estado limitado a `pending`, `confirmed`, `cancelled`, `expired`; expira em cinco minutos. |

Datas são armazenadas em UTC. `timezone` preserva o fuso de exibição informado na solicitação. `total_duration_seconds` não é coluna fonte de verdade: é calculado pela soma de intervalos fechados, com intervalo ativo calculado no momento da leitura.

## Transações e idempotência

1. `POST /commands` valida autenticação e corpo antes de chamar a IA.
2. Em uma transação, o backend cria `voice_requests` com `request_id` único e status `processing`.
3. Se o mesmo `request_id` já possuir `response_json`, devolve exatamente a resposta armazenada, sem chamar a IA nem repetir mudança de estado.
4. Se existir o mesmo `request_id` ainda em `processing`, responde `409 request_in_progress`; o cliente pode tentar novamente com o mesmo ID.
5. A mudança de tarefa, o fechamento/resolução de `pending_actions` e a gravação da `AssistantResponse` final acontecem na mesma transação.
6. Uma falha reverte a transação ou grava uma resposta `error` segura; nunca deixa uma mudança de tarefa sem resposta idempotente associada.

## Erros públicos

| HTTP | Código estável | Quando usar |
| --- | --- | --- |
| 400 | `invalid_request` | JSON ou campos obrigatórios inválidos. |
| 401 | `unauthenticated` | Token ausente, inválido, revogado ou senha incorreta. |
| 403 | `forbidden` | Recurso não pertence à sessão de Samuel. |
| 404 | `not_found` | Tarefa ou ação pendente não encontrada. |
| 409 | `request_in_progress` / `invalid_state` | Mesmo `request_id` em processamento ou transição incompatível. |
| 410 | `pending_action_expired` | Confirmação recebida após cinco minutos. |
| 422 | `needs_clarification` | Ambiguidade de tarefa ou confirmação vocal. |
| 502 | `interpretation_unavailable` | IA indisponível ou resposta incompatível; sem mudança persistente. |

## Limites de segurança

- `OPENAI_API_KEY` existe apenas no ambiente do backend; Flutter nunca a recebe.
- Logs e respostas ao cliente não incluem segredo, token ou conteúdo técnico sensível.
- A IA recebe o texto transcrito e somente o contexto mínimo necessário; não recebe acesso direto à base.
- Operações que alteram tarefas são transacionais: ou a mudança e o registro da solicitação são concluídos juntos, ou nada é alterado.

## Configuração de ambiente

| Variável | Sigilo | Uso |
| --- | --- | --- |
| `OPENAI_API_KEY` | secreto | Autenticação da IA; backend somente. |
| `DATABASE_URL` | secreto | Conexão do PostgreSQL do backend. |
| `APP_INITIAL_USERNAME` | não secreto | Valor inicial `Samuel`; usado apenas na primeira inicialização. |
| `APP_INITIAL_PASSWORD` | secreto | Senha inicial; transformada em hash e nunca persistida em texto puro. |
| `APP_ALLOW_INSECURE_TEST_AUTH` | não secreto, desenvolvimento somente | Quando `true`, permite iniciar localmente sem senha apenas para testes. É proibida fora do ambiente de desenvolvimento e assume `false` por padrão. |

Quando a API usa `POSTGRES_PASSWORD` para compor a conexão local, ela deve construir a URL com um gerador seguro de URLs, e não por interpolação de texto. Isso preserva caracteres especiais da senha. O Alembic deve receber essa URL diretamente ao criar o engine, sem passá-la pelo parser do arquivo INI.

## Entrega da Camada 1

Os contratos HTTP, o modelo relacional, as regras de sessão, os erros e a idempotência estão definidos neste POP. Migrações e código só poderão seguir estas definições ou uma atualização prévia deste documento.
