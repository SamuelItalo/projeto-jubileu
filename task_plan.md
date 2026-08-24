# Plano de Tarefas

## Protocolo 0 — Inicialização

- [x] Etapa 1: Inicializar a memória do projeto.
- [x] Etapa 2: Inicializar `gpeto.md` como a Constituição do Projeto.
- [x] Etapa 3: Interromper a execução e registrar os pré-requisitos para criação de ferramentas.

## Portão obrigatório antes de `tools/`

- [x] Perguntas de descoberta respondidas.
- [x] Schema de dados de entrada e saída definido em `gpeto.md`.
- [x] Blueprint aprovado.

**Estado:** liberado. Os pré-requisitos de descoberta, schemas e blueprint foram concluídos; a criação de ferramentas continua condicionada à verificação das conexões da Fase 2 — Link.

## Próximas fases

- [x] V — Visão e descoberta: perguntas de descoberta respondidas.
- [x] V — Definir e confirmar o schema JSON de entrada e saída em `gpeto.md`.
- [x] V — Pesquisa técnica e de referências para o MVP.
- [x] L — Link e conectividade (OpenAI, Docker, Docker Compose e toolchain Flutter Linux verificados).
- [x] A — Arquitetura: Camada 1 — POPs técnicos concluída em 2026-08-20.
- [ ] A — Arquitetura: Camada 2 — Navegação e orquestração (em preparação).
- [ ] E — Estilo.
- [ ] G — Gatilho e implantação.

## Estado do blueprint

Blueprint aprovado pelo usuário em 2026-08-18:

1. Flutter para Linux como cliente, com tela diária, tarefa ativa, cronômetro e modal de relato por voz/texto.
2. FastAPI como API local, responsável por validar os contratos, orquestrar a interpretação por IA e aplicar regras de confirmação.
3. PostgreSQL em Docker Compose como única persistência de tarefas, intervalos de tempo, notas, transcrições, preferências e resultados de interpretação.
4. IA em nuvem recebe somente o texto transcrito e devolve ações estruturadas; o backend valida o resultado e nunca executa ações sem a confirmação exigida.
5. O MVP não inclui Google Calendar, áudio contínuo, palavra de ativação, texto-para-fala, notificações nem implantação em VPS.

A Fase 2 — Link pode começar.
