# Projeto Jubileu

Assistente pessoal local orientado por voz. O backend recebe transcrições, aplica regras determinísticas e usará IA apenas para propor interpretações estruturadas.

## Estado atual

A fundação da Camada 3 está pronta: FastAPI, PostgreSQL, migração Alembic, autenticação local e testes básicos. O processamento completo de comandos ainda será implementado.

O interpretador inicial é local, determinístico e gratuito. Ele não chama nenhum serviço de IA.

## Comandos disponíveis

Use um comando por vez, ou separe criações por `;`:

- `criar tarefa Preparar relatório`
- `iniciar Preparar relatório`
- `pausar Preparar relatório`
- `retomar Preparar relatório`
- `concluir Preparar relatório`
- `adicionar nota em Preparar relatório: revisei a introdução`

Criar tarefas sempre pede uma confirmação explícita: responda `confirmo` para criar ou `cancelo` para descartar. Frases fora dessa gramática recebem uma pergunta de esclarecimento.

## Executar localmente

1. Copie `.env.example` para `.env` e defina um valor local para `POSTGRES_PASSWORD`.
2. Para testar sem senha inicial, mantenha `APP_ENVIRONMENT=development` e defina `APP_ALLOW_INSECURE_TEST_AUTH=true`. Não use essa opção fora da máquina local.
3. Inicie os serviços:

   ```bash
   docker-compose up --build
   ```

4. A API estará em `http://127.0.0.1:8000`, com documentação em `http://127.0.0.1:8000/docs`. As migrações são executadas automaticamente antes da API iniciar.

## Testes

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest -q
```

## Limpeza local

```bash
docker-compose down
```

Use `docker-compose down -v` somente quando quiser apagar também os dados locais do PostgreSQL.
