# POP 02 — Ciclo de vida e tempo das tarefas

## Objetivo

Manter estados e duração de cada tarefa consistentes, auditáveis e calculados de forma determinística.

## Estados permitidos

- `pending`: criada, sem intervalo ativo.
- `in_progress`: possui exatamente um intervalo ativo, sem horário de fim.
- `paused`: não possui intervalo ativo; pode ter intervalos históricos.
- `completed`: não possui intervalo ativo, é definitivo e não aceita novas transições no MVP. Para trabalho posterior, o usuário cria uma nova tarefa.

## Transições autorizadas

| Comando explícito | Estado de origem | Estado resultante | Efeito |
| --- | --- | --- | --- |
| Iniciar | `pending` | `in_progress` | Abre intervalo com `started_at`. |
| Pausar | `in_progress` | `paused` | Fecha o intervalo ativo com `ended_at`. |
| Retomar | `paused` | `in_progress` | Abre novo intervalo. |
| Concluir | `in_progress` | `completed` | Fecha o intervalo ativo. |
| Concluir | `pending` ou `paused` | `completed` | Não cria intervalo; registra conclusão. |

Todas as transições exigem um comando explícito do usuário e uma tarefa identificada sem ambiguidade. Transições não listadas são rejeitadas e não modificam dados.

Há no máximo uma tarefa em `in_progress` por usuário. Portanto, iniciar ou retomar uma tarefa enquanto houver outra ativa é rejeitado com `409 invalid_state`; Samuel deve pausá-la ou concluí-la antes.

## Cálculo de duração

`total_duration_seconds` é a soma de `ended_at - started_at` de todos os intervalos fechados. Um intervalo ativo pode ser exibido ao usuário com duração corrente calculada no instante da leitura, mas seu valor persistido só é consolidado ao fechar o intervalo. Datas devem ser armazenadas com fuso ou normalizadas em UTC, preservando o fuso informado para exibição.

## Invariantes

- Uma tarefa não possui mais de um intervalo ativo.
- Um usuário não possui mais de uma tarefa em `in_progress`.
- `ended_at` nunca é anterior a `started_at`.
- Uma tarefa `completed` não possui intervalo aberto.
- Uma tarefa `completed` não pode ser reaberta, alterada para outro estado nem receber novo intervalo no MVP.
- Notas, humor e observações não alteram estado nem duração.
- O servidor, e não Flutter nem IA, é a autoridade do estado e do cálculo de tempo.

## Casos de borda

| Situação | Tratamento |
| --- | --- |
| Pausar ou retomar tarefa sem alvo único | Pedir esclarecimento. |
| Iniciar tarefa já `in_progress` | Rejeitar sem abrir outro intervalo. |
| Iniciar ou retomar com outra tarefa ativa | Rejeitar sem alterar a tarefa atual. |
| Pausar ou concluir sem intervalo aberto | Rejeitar a transição incompatível. |
| Relógio do cliente inconsistente | Usar o horário do servidor para registrar transições; preservar `occurred_at` como contexto da solicitação. |
