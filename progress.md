# Progresso

## 2026-08-15

- Lido e compreendido o protocolo V.L.A.E.G. em `Passo-a-Passo/prootocolo-vlaeg.md`.
- Concluída a etapa 1 do Protocolo 0: criados os arquivos de memória `task_plan.md`, `findings.md` e `progress.md`.
- Nenhum script, ferramenta, esquema de dados ou integração foi criado nesta etapa.
- Concluída a etapa 2 do Protocolo 0: criado `gpeto.md` como Constituição do Projeto, com schemas provisoriamente pendentes, regras comportamentais e invariantes arquiteturais.
- Concluída a etapa 3 do Protocolo 0: a execução de scripts e ferramentas foi formalmente bloqueada até a conclusão das perguntas de descoberta, dos schemas de dados e da aprovação do blueprint.
- Iniciada a Fase 1 — Visão, passo 1 (Descoberta): a Estrela Guia foi respondida.
- Descoberta: a integração do MVP foi definida como Google Calendar via OAuth 2.0, com armazenamento local para os demais dados.
- Descoberta: PostgreSQL foi definido como fonte de verdade persistente, com Flutter como cliente multiplataforma e Google Calendar como contexto complementar.
- Descoberta: o payload do MVP foi definido como uma experiência Flutter orientada por voz, com criação e controle de tarefas, cronômetro e visão diária objetiva.
- Concluída a Fase 1 — Visão, passo 1 (Descoberta): as cinco perguntas foram respondidas e as regras comportamentais foram registradas em `gpeto.md`.

## 2026-08-18

- Concluída a Fase 1 — Visão, passo 2: definido e confirmado o schema JSON de entrada `VoiceCommandRequest` e o schema de saída `AssistantResponse` em `gpeto.md`.
- Registrados os estados de processamento e de tarefa, a confirmação obrigatória para criação de tarefas e o cálculo determinístico da duração total.
- Registrada como futura a avaliação do Open Jarvis para áudio; nenhuma pesquisa, decisão técnica ou integração foi realizada nesta etapa.
- O portão para `tools/` permanece bloqueado exclusivamente pela ausência de blueprint aprovado.
- Concluída a pesquisa técnica da Fase 1: Flutter tem suporte oficial ao desktop Linux; FastAPI, PostgreSQL e Docker Compose atendem à execução local e à futura migração para VPS.
- Definidos para o MVP: Ubuntu 24.04, Flutter Linux, FastAPI, PostgreSQL local em Docker Compose e IA em nuvem para interpretação de texto transcrito.
- O Google Calendar e os recursos de áudio contínuo permanecem fora da primeira entrega. Um blueprint foi incluído no `task_plan.md` e aguarda aprovação.
- Blueprint aprovado pelo usuário. A Fase 1 — Visão está concluída e a Fase 2 — Link foi iniciada.
- Verificação inicial da Fase 2: Docker, Docker Compose e Python estão operacionais; Flutter não está instalado e não há `.env` ou credenciais de IA para validar.
- A conclusão da Fase 2 depende da escolha do provedor de IA, da configuração segura da respectiva chave no `.env` e da instalação do Flutter para o cliente Linux.
- OpenAI selecionada como provedor. Criados `.env.example` e `.gitignore` para orientar a configuração local e impedir o versionamento do `.env`; a chave real permanece pendente de criação e inserção pelo usuário.
- Concluído o handshake com a OpenAI: `GET /v1/models` respondeu HTTP 200. Criada e testada a ferramenta determinística `tools/verify_openai_connection.py`, que valida a autenticação sem exibir ou gravar a chave.
- Instalados Flutter `3.47.0` e Dart `3.13.0` no diretório do usuário; o caminho do SDK foi incluído em `/home/ixcsoft/.bashrc`.
- `flutter doctor -v` confirmou Flutter, rede e dispositivo Linux. A toolchain Linux continua pendente somente pela ausência de `libgtk-3-dev`, cuja instalação requer senha de `sudo` do usuário.

## 2026-08-19

- Concluída a Fase 2 — Link, etapa 1 (Verificação): `OPENAI_API_KEY` está configurada no `.env` e o handshake da OpenAI retornou HTTP 200, com 118 modelos acessíveis.
- Docker `29.1.3` e o daemon local estão operacionais. O Compose disponível neste ambiente é o comando legado `docker-compose` (`v2.29.2`); `docker compose` não está instalado.
- A dependência `libgtk-3-dev` foi instalada e `flutter doctor -v` confirmou a toolchain Linux sem pendências.
- O `.env.example` foi verificado sem uma chave de API com formato real. Ainda não há backend ou arquivo Compose do projeto; ambos serão criados na Fase 3 — Arquitetura.
- Iniciada a Fase 3 — Arquitetura, Camada 1: criados os POPs para processamento de comandos, ciclo de vida/tempo das tarefas e fronteiras entre Flutter, API, IA e PostgreSQL. Nenhum código de aplicação foi criado.
- Identificada uma pendência que bloqueia a especificação da API: o contrato atual recebe `intent` e `actions` do Flutter, mas o blueprint atribui a interpretação desses dados à IA orquestrada pelo FastAPI. A decisão será solicitada ao usuário antes de alterar o schema ou implementar endpoints.
- Decisão de contrato confirmada pelo usuário: Flutter envia somente a transcrição e metadados; FastAPI chama a OpenAI e valida o contrato interno `InterpretedCommand`. `gpeto.md` e os POPs foram atualizados antes de qualquer código.
- Definidos para o MVP: usuário local único Samuel com senha armazenada somente como hash e confirmação/cancelamento preferencial por voz. Tarefas de nomes semelhantes sempre exigem esclarecimento. Criado o POP de acesso local e confirmação por voz; a validade de ações pendentes ainda requer decisão.
- Definida a validade de uma ação pendente: cinco minutos após sua criação. Confirmações posteriores não produzem alteração e exigem novo comando.
- Definido que a sessão de Samuel persiste após reiniciar o aplicativo até logout explícito, sem apagar registros. Tarefas concluídas são definitivas no MVP; trabalho posterior requer nova tarefa.

## 2026-08-20

- Concluída a Camada 1 da Fase 3 — Arquitetura. O POP 03 agora define endpoints HTTP, autenticação de sessão, tabelas PostgreSQL, índices e invariantes, erros públicos, variáveis de ambiente e idempotência por `request_id`.
- O contrato de confirmação por voz passou a usar contexto opaco de confirmação, vinculando a nova fala a uma ação pendente do usuário autenticado.
- Nenhum código de aplicação, migração ou serviço foi criado nesta etapa; a próxima camada é Navegação e orquestração.

## 2026-08-24

- Confirmado que a criação de tarefas sempre exige confirmação vocal explícita no MVP; a preferência que permitiria desativá-la foi removida da arquitetura.
- Ratificado o contexto de confirmação por grupo e item: `confirmation_context` usa `group_id` e `action_id` opcional. O modelo relacional agora prevê `pending_action_groups` para persistir essa relação de modo determinístico.
- Autorizado modo de autenticação sem senha somente para testes locais, mediante `APP_ALLOW_INSECURE_TEST_AUTH=true`; ele permanece desabilitado por padrão e proibido fora de desenvolvimento.
- Corrigido o valor de exemplo de `OPENAI_API_KEY` em `.env.example`.
- Concluída a Camada 2 — Navegação e orquestração. O POP 05 define a decisão por rota, idempotência, confirmação vocal determinística, resolução de grupos e o limite transacional de ações múltiplas.
- Iniciada a Camada 3 — Ferramentas e implementação: criado o esqueleto FastAPI, Docker Compose, modelos SQLAlchemy, configuração de segurança, migração Alembic inicial e testes de sanidade. O processamento completo de comandos e o adaptador da IA permanecem para o próximo incremento.
- Validação de integração concluída em ambiente temporário: PostgreSQL iniciou, a migração Alembic `20260824_0001` foi aplicada e a API respondeu `200` em `/health`. O ambiente temporário e seu volume foram removidos após o teste.
- Corrigida a inicialização com senhas PostgreSQL que contêm caracteres especiais: a URL agora é construída de forma segura e o Alembic a usa diretamente. Validação repetida com sucesso: banco e API permanecem ativos, migração aplicada e `/health` retorna `200`.

## 2026-08-25

- Instituído e implementado o interpretador determinístico local, gratuito e sem transmissão de dados. Ele reconhece criação, início, pausa, retomada, conclusão e nota por uma gramática explícita; a criação continua exigindo confirmação vocal.
- Validação de integração do parser concluída: `criar tarefa teste do parser` retornou confirmação pendente e `cancelo` resolveu a ação como rejeitada, sem criar tarefa. A API continuou saudável.

## 2026-08-26

- Implementado `GET /v1/day`: retorna tarefas visíveis no dia consultado, tarefa ativa e duração diária calculada pela sobreposição dos intervalos ao dia no fuso do usuário.
- Instituída a regra de uma única tarefa em andamento por usuário, validada pelo serviço e reforçada no PostgreSQL pela migração `20260826_0002`.
- Validação concluída: 15 testes automatizados passaram; contêineres saudáveis, Alembic em `20260826_0002 (head)` e consulta autenticada de 2026-08-25 retornou a tarefa de teste com 262 segundos.
- Criado o cliente Flutter Linux em `frontend/`: login, restauração de sessão no armazenamento seguro, visão diária, cronômetro local de exibição, comandos por texto e confirmação/cancelamento vinculados ao contexto opaco do backend.
- `flutter analyze` e o teste de widget passaram. A compilação Linux permanece pendente somente de `libsecret-1-dev`, dependência de desenvolvimento exigida pelo armazenamento seguro do Linux; a instalação requer senha local de `sudo`.
- Após a instalação de `libsecret-1-dev`, a compilação Linux foi concluída com sucesso em `frontend/build/linux/x64/debug/bundle/jubileu_app`. API e banco permaneceram saudáveis, e o aplicativo foi iniciado no desktop local. A Camada 3 — implementação está concluída.
- A visão diária passou a incluir observações de cada tarefa. A interface Flutter as exibe ao expandir o cartão da tarefa; a validação autenticada confirmou a observação já registrada em `teste da interface`.
