# POP 01 — Processamento de comandos

## Objetivo

Receber um relato já transcrito, produzir uma interpretação estruturada e devolver ao Flutter uma `AssistantResponse` que respeite confirmação, esclarecimento e segurança. Nenhuma mudança persistente ocorre antes da autorização exigida.

## Entradas e saídas

- Entrada contratada: `VoiceCommandRequest`, contendo somente a transcrição e metadados, conforme `gpeto.md`.
- Saída contratada: `AssistantResponse`, conforme `gpeto.md`.
- Contrato interno: `InterpretedCommand`, produzido pelo interpretador selecionado e validado pelo FastAPI, conforme `gpeto.md`.
- Dependências: tarefas existentes e interpretador configurado. O padrão é o parser determinístico local; no modo `hybrid_ollama`, uma LLM local é usada somente como fallback para frases fora da gramática. No modo `ollama_first`, ela interpreta primeiro comandos de voz e o parser determinístico é a reserva.

## Fluxo

1. Validar campos obrigatórios, UUID, data/hora com fuso, `source` e transcrição não vazia.
2. Rejeitar uma entrada inválida com `status: rejected` ou `error`; não gravar nem alterar tarefa.
3. Sem `confirmation_context`, aplicar o interpretador configurado. No modo `ollama_first`, enviar a transcrição de voz ao Ollama local e validar integralmente o JSON; em falha, indisponibilidade ou JSON inválido, usar o parser determinístico. No modo `hybrid_ollama`, executar primeiro o parser determinístico e consultar Ollama somente se ele não reconhecer a frase.
4. Verificar se as ações candidatas se referem a tarefa existente de maneira inequívoca.
5. Se faltar informação, existir mais de uma tarefa compatível ou a intenção for `unknown`, responder `needs_clarification`, preencher `clarification_question` e não executar ação. Tarefas com nomes semelhantes sempre exigem esclarecimento; o sistema pode oferecer criar uma nova, sem presumi-la.
6. Para `create_task`, construir tarefas candidatas e sempre responder `awaiting_confirmation`; a confirmação por voz é obrigatória no MVP e as tarefas não são persistidas antes dela.
7. Para iniciar, pausar, retomar, concluir ou adicionar nota, exigir comando explícito e alvo único. Aplicar somente após a autorização indicada pelo contrato e pelas regras comportamentais.
8. Depois da ação autorizada e validada, persistir uma única transação e responder `completed` com a representação atual das tarefas afetadas.

## Regras determinísticas

- Uma fala pode originar várias ações. Elas formam um grupo de confirmação: o usuário pode confirmá-lo/cancelá-lo por inteiro ou confirmar/cancelar cada item individualmente.
- O interpretador só pode sugerir intenção e campos candidatos; não tem acesso ao PostgreSQL, não decide confirmação e não executa alterações.
- O Ollama recebe um prompt de JSON estrito, possui timeout curto e só pode devolver os seis tipos de ação já existentes. JSON inválido, campos vazios, falha ou indisponibilidade devolvem esclarecimento, nunca uma ação parcial.
- A criação de tarefa nunca é persistida enquanto estiver em `awaiting_confirmation`.
- Uma resposta sempre conserva o mesmo `request_id` da entrada.
- Retentativas do mesmo `request_id` não podem duplicar alterações já concluídas; elas devolvem a resposta já persistida, conforme a estratégia de idempotência definida no POP 03.

## Casos de borda

| Situação | Resposta esperada |
| --- | --- |
| Texto vazio ou só espaços | `rejected`, sem persistência. |
| Duas tarefas com nome semelhante | `needs_clarification`, apresentando opções suficientes para escolha. |
| Múltiplas tarefas em um relato | Candidatas separadas; confirmação clara de cada item. |
| Comando fora da gramática determinística | `needs_clarification`, sem alteração de tarefa e com exemplos válidos. |
| Falha ou JSON inválido de futura IA | `error`, sem alteração de tarefa; registrar detalhe técnico seguro. |
| Confirmação negativa | `rejected`, descartando somente a ação pendente. |
| Confirmação vocal sem ação pendente única | `needs_clarification`, sem alteração. |

## Decisão de contrato adotada

O Flutter envia somente `VoiceCommandRequest` com a transcrição e metadados. O FastAPI chama o interpretador configurado, valida o `InterpretedCommand` interno e permanece como única autoridade para confirmação, estado e persistência.

## Gramática determinística inicial

Os comandos são normalizados sem diferenciar maiúsculas, acentos ou pontuação. A primeira versão aceita uma ação por fala, ou várias ações separadas por `;`:

- `criar tarefa <título>` ou `crie tarefa <título>`;
- `iniciar <título>`;
- `pausar <título>`;
- `retomar <título>`;
- `concluir <título>`;
- `adicionar nota em <título>: <observação>`.

Frases fora dessa gramática exigem esclarecimento. O título e a observação preservam a grafia informada pelo usuário.
