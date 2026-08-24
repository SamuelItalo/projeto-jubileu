# Gpeto — Constituição do Projeto

## Identidade e estado

- **Protocolo:** V.L.A.E.G. — Visão, Link, Arquitetura, Estilo e Gatilho.
- **Arquitetura:** A.N.T. — Arquitetura, Navegação e Ferramentas.
- **Estado atual:** Fases 1 — Visão e 2 — Link concluídas. Na Fase 3 — Arquitetura, as Camadas 1 (POPs técnicos) e 2 (navegação e orquestração) estão concluídas; a Camada 3 — ferramentas e implementação está em andamento.
- **Objetivo do projeto:** criar um assistente pessoal inteligente, orientado por voz, que acompanhe o trabalho do usuário, registre atividades, meça o tempo por tarefa e produza insights práticos de produtividade.

## Fonte de verdade e componentes

- **Fonte de verdade:** PostgreSQL, responsável pela persistência e consulta dos dados do assistente.
- **Cliente:** Flutter, para interface e captura de interações em Linux, Windows, macOS, Android e iOS.
- **Fonte complementar:** Google Calendar, usado apenas como contexto de compromissos e planejamento diário; nunca como fonte primária de produtividade.
- **Escopo da primeira entrega:** operação local no Ubuntu 24.04, sem integração com Google Calendar.
- **Backend:** Python com FastAPI.
- **Infraestrutura inicial:** PostgreSQL e API executados localmente com Docker Compose; a futura migração para VPS deverá preservar a mesma composição de serviços.
- **IA:** serviço de IA em nuvem para interpretar texto já transcrito e devolver dados estruturados compatíveis com os schemas deste documento.

## Esquemas de dados

Os schemas abaixo foram confirmados para o MVP. O áudio é transcrito antes de chegar ao contrato de entrada; a tecnologia de transcrição permanece uma decisão futura.

### Entrada

- **Status:** definido e confirmado.
- **Origem:** Flutter, após captura e transcrição da interação por voz.
- **Formato:** objeto JSON `VoiceCommandRequest`.
- **Campos obrigatórios:** `request_id`, `occurred_at`, `timezone`, `source` e `transcript`.

```json
{
  "request_id": "uuid",
  "occurred_at": "2026-08-18T14:30:00-03:00",
  "timezone": "America/Recife",
  "source": "voice",
  "transcript": "Comecei a preparar o relatório e pausei a revisão do orçamento",
  "confirmation_context": null
}
```

- `source` será `voice` no MVP.
- O Flutter envia apenas a transcrição e seus metadados; ele não interpreta intenção, não produz ações e não informa se uma confirmação é necessária.
- `confirmation_context` é opcional e só é enviado ao confirmar ou cancelar por voz uma ação pendente apresentada pelo backend. Ele contém a referência opaca do grupo e, opcionalmente, de um item; ambas são validadas pelo servidor e pertencem à sessão de Samuel.
- O FastAPI envia somente o texto e o contexto mínimo necessário à IA em nuvem, valida a resposta e produz internamente ações candidatas.

### Contrato interno de interpretação

- **Status:** definido para uso exclusivo entre o orquestrador FastAPI e o adaptador de IA; não é exposto ao Flutter.
- **Formato:** objeto JSON `InterpretedCommand`.

```json
{
  "intent": "create_task",
  "actions": [
    {
      "type": "create_task",
      "task": {
        "title": "Preparar o relatório",
        "description": null,
        "category": null,
        "priority": null,
        "mood": null
      },
      "task_reference": null,
      "note": null
    }
  ]
}
```

- `intent` aceita: `create_task`, `start_task`, `pause_task`, `resume_task`, `complete_task`, `add_note`, `query_day` e `unknown`.
- `actions` pode conter múltiplos itens; cada item é validado e tratado individualmente.
- `type` deve ser compatível com a intenção; `task` é usado em `create_task`, `task_reference` identifica uma tarefa existente nas demais ações e `note` é usado em `add_note`.
- O resultado da IA é apenas candidato: FastAPI rejeita campos, tipos ou referências inválidos e nunca o persiste nem executa diretamente.

### Saída (payload)

- **Status:** definido e confirmado.
- **Destino:** interface Flutter e PostgreSQL, quando a ação tiver sido confirmada e aplicada.
- **Formato:** objeto JSON `AssistantResponse`.
- **Critérios de aceite:** toda resposta informa o resultado, preserva a exigência de confirmação e representa tarefas com seu estado e tempos consistentes.

```json
{
  "request_id": "uuid",
  "status": "awaiting_confirmation",
  "message": "Entendi que você quer criar a tarefa “Preparar o relatório”. Confirma?",
  "tasks": [
    {
      "id": "uuid",
      "title": "Preparar o relatório",
      "description": null,
      "status": "pending",
      "created_at": "2026-08-18T14:30:00-03:00",
      "started_at": null,
      "ended_at": null,
      "total_duration_seconds": 0,
      "notes": [],
      "mood": null
    }
  ],
  "suggestions": [],
  "requires_confirmation": true,
  "clarification_question": null,
  "confirmation_context": {
    "group_id": "uuid",
    "action_id": null,
    "expires_at": "2026-08-20T14:35:00-03:00"
  }
}
```

- `status` aceita: `awaiting_confirmation`, `completed`, `needs_clarification`, `rejected` e `error`.
- O status da tarefa aceita: `pending`, `in_progress`, `paused` e `completed`.
- `total_duration_seconds` é calculado deterministicamente pela soma dos intervalos ativos da tarefa.
- `clarification_question` deve ser preenchido quando a fala for ambígua, incompleta ou corresponder a tarefas semelhantes.
- `confirmation_context` é preenchido somente quando `status` for `awaiting_confirmation`; nos demais casos é `null`. Ele contém referências opacas para a confirmação por voz e expira em cinco minutos.

## Regras comportamentais

- Priorizar confiabilidade e comportamento determinístico sobre velocidade.
- Não supor lógica de negócio: solicitar ou registrar informações ausentes.
- A lógica de negócio deve estar em ferramentas determinísticas e testáveis; a camada de navegação apenas decide e orquestra.
- Usar tom amigável, prático, respeitoso e sem julgamentos; apresentar informações de forma curta e acionável.
- Antes de criar uma tarefa reconhecida por voz, apresentar a interpretação e pedir confirmação explícita. Essa confirmação é sempre obrigatória no MVP.
- No MVP, Samuel confirma ou cancela ações pendentes obrigatoriamente por voz. A confirmação deve ser explícita e não pode ampliar a intenção original. Para ações múltiplas, o contexto contém `group_id` e, opcionalmente, `action_id`.
- Quando uma fala produzir várias ações, Samuel pode confirmar ou cancelar todo o grupo com uma única frase explícita, ou confirmar/cancelar itens individuais. Cada item permanece rastreável por referência opaca.
- Uma ação pendente expira cinco minutos após sua criação. Após expirar, nenhuma confirmação pode aplicá-la; o usuário deve enviar novo comando.
- Em caso de fala ambígua, incompleta, com mais de uma interpretação possível ou referência a tarefas de nomes semelhantes, pedir esclarecimento em vez de assumir uma ação.
- Quando houver tarefa de nome semelhante, sempre pedir esclarecimento; pode oferecer a criação de uma nova tarefa, mas nunca a cria nem seleciona uma existente sem a confirmação explícita do usuário.
- Nunca iniciar, pausar, retomar ou finalizar tarefas automaticamente: essas transições exigem comando explícito do usuário.
- Pode sugerir prioridades e horários com base no histórico, duração, horários produtivos, humor e compromissos do Google Calendar, mas nunca pode criar ou modificar tarefas ou compromissos sem aprovação explícita.
- Nunca excluir registros, alterar dados históricos, iniciar cronômetros, encerrar tarefas ou modificar o Google Calendar sem autorização explícita do usuário.
- Evitar excesso de notificações ou mensagens.
- Manter segredos e tokens exclusivamente em `.env`; nunca registrá-los em arquivos de memória ou código.
- Usar `.tmp/` apenas para dados intermediários e efêmeros.
- O MVP é local e possui inicialmente um único usuário, Samuel. Ele acessa a aplicação com senha; apenas seu hash pode ser persistido e o valor em texto puro deve permanecer em variável de ambiente exclusiva do backend.
- Depois da autenticação, a sessão de Samuel permanece ativa ao reiniciar o aplicativo até logout explícito. Tarefas, intervalos e demais ações registradas nunca são apagados pelo reinício do aplicativo.
- Uma tarefa concluída é definitiva no MVP: ela não pode ser reaberta ou receber novos intervalos; para trabalho posterior, Samuel deve criar nova tarefa.
- Atualizar `progress.md` após cada tarefa significativa e `findings.md` quando houver descobertas ou restrições.

## Invariantes arquiteturais

- `architecture/` conterá POPs técnicos em Markdown, definidos ou atualizados antes de mudanças na lógica correspondente.
- `tools/` conterá scripts atômicos, determinísticos e testáveis.
- Nenhum script em `tools/` será criado antes de: responder às perguntas de descoberta, confirmar os schemas de dados e aprovar o blueprint no `task_plan.md`.
- Integrações externas serão verificadas na fase Link antes da implementação da lógica completa.
- Cada falha de ferramenta deverá ser analisada, corrigida, testada e documentada no POP correspondente.

## Controle de mudanças

Atualize este documento somente quando um schema, regra comportamental ou invariante arquitetural for criado ou alterado.

## Log de manutenção

| Data | Alteração | Motivo |
| --- | --- | --- |
| 2026-08-15 | Constituição inicial criada. | Cumprimento da etapa 2 do Protocolo 0. |
| 2026-08-15 | Bloqueio de execução registrado. | Cumprimento da etapa 3 do Protocolo 0. |
| 2026-08-15 | Fonte de verdade e componentes definidos. | Registro da decisão de descoberta sobre persistência, cliente e contexto externo. |
| 2026-08-15 | Regras comportamentais definidas. | Conclusão da descoberta da Fase 1. |
| 2026-08-18 | Schemas de entrada e saída confirmados. | Conclusão da Fase 1, passo 2 — Dados Primeiro. |
| 2026-08-18 | Stack e escopo do MVP definidos. | Preparação do blueprint após pesquisa da Fase 1. |
| 2026-08-18 | Blueprint aprovado. | Liberação do portão para iniciar a Fase 2 — Link. |
| 2026-08-19 | Estado atualizado para a Fase 3 e POPs técnicos instituídos em `architecture/`. | Início da Camada 1 da arquitetura A.N.T. |
| 2026-08-19 | Contrato de entrada revisado e contrato interno `InterpretedCommand` criado. | Decisão do usuário de adotar o fluxo recomendado no blueprint: interpretação exclusiva pelo FastAPI/IA. |
| 2026-08-19 | Acesso local de usuário único e confirmação preferencial por voz definidos. | Decisões arquiteturais do usuário para o MVP. |
| 2026-08-19 | Expiração de ações pendentes definida em cinco minutos. | Regra de confirmação por voz definida pelo usuário. |
| 2026-08-19 | Persistência de sessão e encerramento definitivo de tarefas definidos. | Decisões do usuário para concluir regras do MVP. |
| 2026-08-20 | Referência opaca de ação pendente adicionada aos contratos de comando e resposta. | Vincular confirmação por voz de forma determinística e segura. |
| 2026-08-20 | Confirmação vocal obrigatória e grupos de ações definidos. | Decisões do usuário para a Camada 2 de navegação. |
| 2026-08-24 | Confirmação de criação tornou-se obrigatória e o contexto de grupos foi ratificado. | Decisões do usuário antes da implementação. |
| 2026-08-24 | Navegação e orquestração definidas. | Conclusão da Camada 2 da arquitetura A.N.T. |
| 2026-08-24 | Fundação executável da Camada 3 criada e validada. | Início da implementação com FastAPI, PostgreSQL, Alembic e Docker Compose. |
