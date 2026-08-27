# Descobertas

## Protocolo adotado

- O projeto seguirá V.L.A.E.G.: Visão, Link, Arquitetura, Estilo e Gatilho.
- A arquitetura prevista é A.N.T., com POPs em `architecture/`, navegação decisória e ferramentas determinísticas em `tools/`.
- Nenhuma ferramenta ou script deve ser criado antes de concluir a descoberta, definir o esquema de dados em `gpeto.md` e aprovar o blueprint em `task_plan.md`.

## Restrições atuais

- **Estrela Guia definida:** criar um assistente pessoal inteligente, orientado por voz, que acompanhe o trabalho do usuário, registre suas atividades, meça o tempo por tarefa e transforme esses dados em insights práticos de produtividade.
- O usuário deve poder relatar suas atividades naturalmente por voz, sem documentação manual; o sistema deverá identificar padrões e gargalos e sugerir a priorização diária com base no histórico real de execução.
- **Integração do MVP definida:** somente Google Calendar, para fornecer contexto de compromissos à organização do dia, ao registro de atividades e à análise de produtividade.
- A autenticação do Google Calendar usará OAuth 2.0; as credenciais ainda não foram configuradas.
- Documentação por voz, tarefas, tempos, métricas e análises serão armazenados localmente na aplicação no MVP.
- Notion, Slack, Teams, e-mail, WhatsApp e gerenciadores de tarefas estão fora do escopo do MVP.
- **Fonte da verdade definida:** PostgreSQL. Ele concentrará transcrições com data e hora, tarefas, tempos de atividade, status, categorias, prioridades, contexto, métricas, histórico, insights, padrões, sugestões e preferências do usuário.
- O Flutter será o cliente multiplataforma (Linux, Windows, macOS, Android e iOS), responsável pela interface e captura de interações.
- O Google Calendar não armazenará os registros de produtividade e não será usado como fonte primária.
- **Payload de entrega definido:** interface Flutter simples, minimalista e orientada por voz. O usuário abrirá uma janela/modal para relatar atividades naturalmente, e a tela principal exibirá tarefa ativa com cronômetro, tarefas do dia, status, tempo gasto e ações rápidas por voz.
- Uma fala pode conter várias tarefas; o sistema deverá identificar e registrar cada item como uma tarefa individual.
- Cada tarefa deverá conter inicialmente: título/descrição, data de criação, status (`pendente`, `em andamento` ou `concluída`), horários de início e fim, duração total, observações/documentação por voz e humor/percepção do usuário quando informado.
- Comandos de voz do MVP incluem iniciar, pausar, concluir e adicionar observação a uma tarefa.
- Notificações e alertas avançados estão fora do escopo inicial; poderão ser avaliados depois para desktop, Android e iOS.
- **Regras comportamentais definidas:** tom amigável, prático, respeitoso e sem julgamentos; respostas curtas e acionáveis.
- A criação de tarefa por voz deve ser confirmada pelo usuário, salvo quando ele tiver desativado explicitamente essa confirmação. Ambiguidades, informações incompletas e tarefas de nomes semelhantes exigem esclarecimento.
- Iniciar, pausar, retomar e finalizar tarefas exigem comando explícito do usuário. Sugestões podem usar histórico, duração, produtividade, humor e agenda, mas não podem modificar tarefas ou compromissos sem aprovação explícita.
- Sem autorização explícita, o assistente não pode excluir registros, alterar histórico, controlar cronômetros, encerrar tarefas ou modificar o Google Calendar.
- Os schemas de entrada e saída foram definidos e confirmados em `gpeto.md`.
- A etapa 3 do Protocolo 0 confirmou o portão para criação de ferramentas; descoberta e schemas estão concluídos, mas o blueprint ainda precisa de aprovação.
- **Schemas confirmados:** o contrato de entrada é `VoiceCommandRequest`, recebido após transcrição de voz; o contrato de saída é `AssistantResponse`, destinado ao Flutter e à persistência no PostgreSQL após confirmação e aplicação da ação.
- Os estados de processamento são `awaiting_confirmation`, `completed`, `needs_clarification`, `rejected` e `error`; os estados de tarefa são `pending`, `in_progress`, `paused` e `completed`.
- A transcrição de áudio não faz parte da implementação atual. O projeto Open Jarvis foi citado como opção para discussão futura, sem decisão ou integração aprovada.

## Pesquisa técnica — 2026-08-18

- Flutter oferece suporte oficial para aplicações desktop Linux; o Ubuntu 24.04 é um alvo compatível, desde que as dependências de desenvolvimento Linux sejam instaladas.
- FastAPI oferece documentação OpenAPI interativa automaticamente e recomenda imagens construídas a partir da imagem oficial do Python para execução em contêineres.
- Docker Compose é adequado para orquestrar localmente API e PostgreSQL e também permite levar a mesma composição a uma VPS posterior.
- A API de IA em nuvem deve produzir saída estruturada aderente ao schema JSON; o backend continua sendo a autoridade determinística que valida e exige confirmação antes de persistir ou alterar tarefas.
- O repositório oficial `open-jarvis/OpenJarvis` é uma plataforma de IA local, com dependências e objetivos mais amplos que o MVP. Pode ser reavaliado quando a transcrição/áudio entrar no escopo; não deve ser incorporado agora.

### Referências consultadas

- [Flutter — suporte desktop](https://docs.flutter.dev/platform-integration/desktop)
- [Flutter — desenvolvimento para Linux](https://docs.flutter.dev/platform-integration/linux/setup)
- [FastAPI — contêineres Docker](https://fastapi.tiangolo.com/deployment/docker/)
- [Docker — Compose](https://docs.docker.com/compose/)
- [OpenJarvis oficial](https://github.com/open-jarvis/OpenJarvis)

## Fase 2 — Link: diagnóstico local — 2026-08-18

- Docker `29.1.3` e Docker Compose `v2.29.2` estão instalados e o daemon Docker responde corretamente.
- Python `3.12.3` está disponível.
- Flutter não está instalado no ambiente atual.
- Ainda não há `.env`, arquivos de Compose ou credenciais de provedor de IA no projeto; portanto, não é possível testar autenticação nem a comunicação com a IA em nuvem.
- O Google Calendar não será verificado nesta fase porque foi adiado explicitamente para uma etapa posterior.
- OpenAI foi escolhido como provedor de IA em nuvem. O segredo será consumido exclusivamente pelo backend FastAPI por meio da variável `OPENAI_API_KEY`; ele não poderá ser enviado ao Flutter.
- A autenticação com a OpenAI foi verificada com sucesso em 2026-08-18: endpoint `GET /v1/models` respondeu HTTP 200. A ferramenta reutilizável `tools/verify_openai_connection.py` executa o mesmo handshake sem exibir a credencial.
- Flutter `3.47.0` (canal stable) e Dart `3.13.0` foram instalados em `/home/ixcsoft/develop/flutter` e adicionados ao `PATH` do Bash.
- A validação `flutter doctor -v` reconheceu o dispositivo Linux e todos os demais componentes de desenvolvimento, exceto as bibliotecas GTK 3 de desenvolvimento. A instalação de `libgtk-3-dev` exige privilégio `sudo` local.

## Fase 2 — Link: verificação concluída — 2026-08-19

- A `OPENAI_API_KEY` está presente no `.env` e o verificador determinístico retornou HTTP 200, confirmando a autenticação com a OpenAI.
- Docker e o daemon local estão disponíveis. O ambiente expõe o Docker Compose pelo comando `docker-compose` (v2.29.2), e não pelo subcomando `docker compose`; os comandos de desenvolvimento devem usar a forma disponível até que o plugin moderno seja instalado.
- A toolchain Linux do Flutter está pronta após a instalação de `libgtk-3-dev`.
- Não há serviço PostgreSQL, backend FastAPI ou arquivo Compose neste momento. Isso não bloqueia o Link: a conexão só poderá ser testada depois que esses componentes forem definidos e iniciados na Fase 3 — Arquitetura.

## Decisão arquitetural — 2026-08-19

- O fluxo recomendado pelo blueprint foi aprovado: Flutter envia somente `VoiceCommandRequest` com transcrição e metadados; o backend FastAPI é o único consumidor da OpenAI.
- A resposta da IA é interna, no formato `InterpretedCommand`, e constitui apenas uma ação candidata. O backend valida, pede confirmação quando aplicável e persiste de modo determinístico.
- O MVP terá somente o usuário local Samuel, protegido por senha configurada localmente e persistida apenas como hash. A confirmação e o cancelamento de ações pendentes serão feitos preferencialmente por voz.
- Referências a tarefas semelhantes não podem ser resolvidas automaticamente: o backend sempre pede esclarecimento e pode oferecer a criação de uma nova tarefa mediante confirmação.
- A sessão autenticada de Samuel deve persistir entre reinicializações do aplicativo até logout explícito. Reiniciar nunca pode remover dados registrados.
- Uma tarefa concluída é definitiva neste MVP e não pode ser reaberta; um novo trabalho exige nova tarefa.

## Camada 1 — Arquitetura concluída — 2026-08-20

- A API prevista usa autenticação local por token opaco de sessão, persistido de modo seguro no Flutter e armazenado apenas como hash no PostgreSQL.
- A repetição de um `request_id` devolve a resposta já registrada e não repete alterações; solicitações ainda em processamento retornam conflito recuperável.
- Confirmações vocais carregam `confirmation_context` opaco, com grupo e item opcional, e são válidas por cinco minutos, sempre verificadas pelo backend.

## Decisões para implementação — 2026-08-24

- A confirmação de criação de tarefa é obrigatória no MVP e não será exposta como preferência configurável.
- A confirmação de ações múltiplas usa `confirmation_context` com `group_id` e `action_id` opcional. A persistência exige registros de grupo e de itens pendentes para permitir resolução total ou individual.
- A ausência de senha é permitida exclusivamente em testes locais, mediante flag explícita de desenvolvimento. O modo é desabilitado por padrão e não pode ser usado fora do ambiente local.

## Camada 3 — fundação validada — 2026-08-24

- O esqueleto FastAPI, PostgreSQL 16, SQLAlchemy 2 e Alembic foi validado em contêineres locais. A migração inicial chegou à revisão `20260824_0001` e a rota `/health` respondeu com sucesso.
- Para executar persistentemente com Docker Compose, o `.env` local precisa definir `POSTGRES_PASSWORD`; o valor não foi criado nem gravado automaticamente.
- Uma senha PostgreSQL com caracteres especiais exige composição segura da URL de conexão. A API passou a construí-la a partir dos campos `POSTGRES_*`, e o Alembic conecta diretamente por essa URL para evitar interpretação indevida de caracteres pelo Compose ou pelo parser INI.

## Parser determinístico — 2026-08-25

- O modo gratuito reconhece comandos locais de criação, início, pausa, retomada, conclusão e anotação. Ele aceita somente a gramática registrada no POP 01 e devolve esclarecimento para frases fora dela.
- A validação de integração confirmou o ciclo seguro de criação pendente e cancelamento por voz, sem persistir a tarefa cancelada.

## Visão diária — 2026-08-26

- A visão diária usa o fuso de `user_preferences` (com `America/Recife` como padrão) para delimitar o início e o fim de cada dia.
- A duração do dia é calculada por sobreposição de intervalos, portanto não duplica tempo que atravessa meia-noite e inclui intervalos ativos até o momento da leitura.
- Uma restrição parcial no PostgreSQL garante que cada usuário tenha no máximo uma tarefa com status `in_progress`.

## Cliente Flutter Linux — 2026-08-26

- `flutter_secure_storage` usa o serviço seguro do sistema no Linux e exige o pacote de desenvolvimento `libsecret-1-dev` para compilar. Não é uma dependência do backend.
- A interface usa o token apenas em memória para chamadas HTTP e o persiste no cofre seguro; mensagens e telas não exibem esse token.
- Com `libsecret-1-dev` instalado, o bundle Linux do Flutter compilou e iniciou normalmente. Uma limpeza do cache (`flutter clean`) foi necessária para descartar um prefixo CMake antigo apontando para `/usr/local`.
- As observações já eram persistidas corretamente em `task_notes`; a lacuna estava somente no contrato de leitura diária e na interface. Não foi necessária migração de banco.
- A interface de produtividade não precisa de imagens externas para parecer refinada: contraste de foco, espaçamento, tipografia leve, superfícies e movimento breve atendem melhor ao fluxo local e preservam rapidez de execução.
- As referências de Samuel convergem em dois padrões úteis: entrada limpa e centrada, e dashboard desktop com barra lateral, cabeçalho objetivo e dados organizados em superfícies compactas. A implementação adotou esses padrões como inspiração, sem incorporar ou reproduzir as imagens.
- O dispositivo padrão de entrada é `alsa_input.pci-0000_00_1f.3.analog-stereo` no PipeWire, correspondente ao codec analógico do notebook. Fones P3 e processamento Easy Effects continuam compatíveis enquanto essa fonte permanecer selecionada pelo sistema.
- O modelo Vosk compacto em português atende ao primeiro teste local com baixo consumo, mas sua precisão deve ser avaliada por Samuel em comandos reais antes de qualquer ajuste de vocabulário ou troca de modelo.
- No primeiro uso real, Vosk reconheceu frases aproximadas mas perdeu palavras de intenção como `criar`. Por isso o ponto de confirmação de texto foi movido para antes do envio ao parser; esse é um controle de confiabilidade, não uma mudança de regra de negócio.
