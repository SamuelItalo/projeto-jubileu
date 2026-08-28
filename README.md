# Projeto Jubileu

Assistente pessoal local orientado por voz. O backend recebe transcrições, aplica regras determinísticas e usará IA apenas para propor interpretações estruturadas.

## Estado atual

A fundação do backend e o primeiro cliente Flutter da Camada 3 estão prontos: FastAPI, PostgreSQL, autenticação local, parser determinístico, visão diária e interface Linux. A entrada atual é textual; captura de áudio ainda não faz parte desta etapa.

O interpretador inicial é local, determinístico e gratuito. Ele não chama nenhum serviço de IA.

## Comando por voz local

O cliente Linux também possui o botão **Segure para falar**. Mantenha-o pressionado enquanto dita um comando em português e solte ao terminar. O áudio é gravado apenas durante o toque, transcrito localmente por Vosk e apagado em seguida; nenhum áudio ou texto é enviado a serviços externos.

O modelo local fica em `models/`, que não é versionado pelo Git. O microfone padrão do PipeWire é usado; se o fone P3 ou Easy Effects mudar a fonte, ajuste-a nas configurações de som do sistema e tente novamente.

A transcrição principal usa Whisper local (`faster-whisper`, modelo `small`) em CPU. Para baixar o modelo após configurar o ambiente Python, execute uma vez na raiz do projeto:

```bash
./.venv/bin/python tools/download_whisper_model.py
```

O Vosk compacto permanece como reserva automática se o Whisper não estiver disponível.

## Resposta por voz local

O Jubileu usa preferencialmente Piper com a voz neural local pt-BR `faber-medium`; não há transmissão de texto, áudio ou uso de serviços de IA na nuvem. Os arquivos do mecanismo estão no ambiente local `.venv/` e a voz está em `models/piper/`, ambos fora do Git. Se eles não estiverem disponíveis, o aplicativo usa `spd-say` como reserva.

Na tela principal, **Testar voz** reproduz uma frase sem criar ou alterar tarefas. A fala também responde a confirmações, resultados, esclarecimentos e erros relevantes.

Para comandos ditados, o fluxo é: segure `F8`, diga o comando e solte; o Jubileu lê a transcrição e pergunta se confirma o envio. Segure `F8` novamente e diga `confirmo` (ou `enviar`) para prosseguir, ou `cancelo` (ou `descartar`) para removê-la. Uma criação de tarefa recebe então a confirmação formal adicional exigida pelo backend; responda `confirmo` ou `cancelo` novamente para concluir essa etapa.

## Interpretação local com Ollama

O padrão continua sendo o parser determinístico, rápido e gratuito. Para entender frases mais naturais sem usar serviços externos, defina no `.env`:

```env
COMMAND_INTERPRETER=ollama_first
OLLAMA_BASE_URL=http://host.docker.internal:11434
OLLAMA_MODEL=qwen3:4b-instruct
```

Nesse modo, cada comando por voz é interpretado primeiro pelo Ollama local. Se ele estiver indisponível ou devolver um resultado inválido, o parser determinístico assume automaticamente. A resposta é restrita a ações permitidas e continua sujeita às confirmações da aplicação. O serviço Ollama precisa estar ativo e acessível ao Docker na porta `11434`.

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

## Cliente Flutter para Linux

O cliente está em `frontend/`. Ele guarda o token de sessão no cofre seguro do Linux, restaura a sessão, exibe a visão diária, atualiza o cronômetro da tarefa ativa e envia comandos textuais para a API local.

Antes da primeira compilação Linux, instale a dependência do cofre seguro:

```bash
sudo apt update
sudo apt install -y libsecret-1-dev
```

Com a API iniciada em outro terminal, execute:

```bash
cd frontend
/home/ixcsoft/develop/flutter/bin/flutter pub get
/home/ixcsoft/develop/flutter/bin/flutter run -d linux
```

O endereço padrão é `http://127.0.0.1:8000/v1`. Para outro endereço ou fuso, use `--dart-define`, por exemplo: `--dart-define=API_BASE_URL=http://127.0.0.1:8000/v1 --dart-define=USER_TIMEZONE=America/Recife`.

## Limpeza local

```bash
docker-compose down
```

Use `docker-compose down -v` somente quando quiser apagar também os dados locais do PostgreSQL.
