# Camada 1 — POPs técnicos

Esta pasta é a fonte operacional da arquitetura A.N.T. Cada POP define objetivo, entradas, saídas, regras determinísticas e casos de borda antes de qualquer lógica correspondente ser criada ou modificada.

## POPs do MVP

1. [Processamento de comandos](01-processamento-de-comandos.md): converte um relato transcrito em uma resposta segura e confirmável.
2. [Ciclo de vida e tempo das tarefas](02-ciclo-de-vida-e-tempo.md): define estados, transições e cálculo de duração.
3. [API, persistência e fronteiras](03-api-persistencia-e-fronteiras.md): define as responsabilidades entre Flutter, FastAPI, IA e PostgreSQL.
4. [Acesso local e confirmação por voz](04-acesso-local-e-confirmacao-por-voz.md): define o usuário único, a senha inicial e a confirmação vocal de ações pendentes.
5. [Navegação e orquestração](05-navegacao-e-orquestracao.md): roteia cada solicitação pelos POPs, pela confirmação e pela persistência.

**Estado da Camada 1:** concluída em 2026-08-20. Os POPs especificam as regras de negócio, contratos externos e internos, persistência, autenticação, erros e idempotência necessários antes da implementação.

**Estado da Camada 2:** concluída em 2026-08-24. O POP 05 fixa a ordem de decisão e os limites entre rotas determinísticas, interpretação por IA e transações.

## Regra de mudança

Qualquer alteração de regra de negócio deve primeiro atualizar o POP aplicável e, quando necessário, `gpeto.md`. Código só poderá implementar comportamento que esteja definido nestes documentos e nos schemas aprovados.
