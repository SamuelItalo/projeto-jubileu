# POP 06 — Áudio local e transcrição

## Objetivo

Permitir que Samuel dite um comando pressionando um botão, sem enviar áudio ou transcrição para serviços externos. O texto reconhecido entra no mesmo fluxo determinístico de `POST /v1/commands`.

## Fluxo

1. O Flutter mostra o botão “Segure para falar”.
2. Enquanto ele estiver pressionado, grava WAV mono PCM de 16 kHz em arquivo temporário do aplicativo.
3. Ao soltar, o Flutter envia o arquivo autenticado a `POST /v1/transcriptions`.
4. A API valida o arquivo e usa o Whisper local (`faster-whisper`, modelo `small`) para devolver somente `{ "transcript": "..." }`. Se o Whisper estiver indisponível ou falhar, usa o Vosk local como reserva.
5. O Flutter preenche o campo de comando com a frase reconhecida, mostra-a e a reproduz por voz. Ela entra em estado local de revisão e **não** é enviada ao `POST /v1/commands` ainda.
6. Samuel pode revisar o texto e usar `F8` novamente para dizer `confirmo`/`enviar` ou `cancelo`/`descartar`. Os botões visuais “Enviar” e “Descartar” fornecem o mesmo controle.
7. Ao confirmar o envio, o Flutter envia a frase original como uma nova `VoiceCommandRequest`. Para criação de tarefa, o backend devolve sua confirmação formal persistida; o Flutter a lê e aceita `confirmo`/`cancelo` por voz, sempre com o `confirmation_context` opaco correspondente.

## Limites e privacidade

- A captura só existe enquanto o botão estiver pressionado; não há escuta contínua, palavra de ativação ou gravação em segundo plano.
- O WAV é temporário e apagado pelo Flutter depois da transcrição, inclusive em erro.
- O backend não persiste o arquivo de áudio; persiste apenas a transcrição já prevista em `voice_requests` quando o comando é enviado.
- Os modelos Whisper e Vosk ficam em `models/`, fora do Git, montados somente-leitura no contêiner da API.
- O endpoint aceita apenas WAV PCM mono, 16 bits e 16 kHz, com limite de 30 segundos e 5 MB. Formato inválido recebe `422 invalid_audio`; modelo indisponível recebe `503 transcription_unavailable`.

## Contrato HTTP

| Método e caminho | Entrada | Saída |
| --- | --- | --- |
| `POST /v1/transcriptions` | `multipart/form-data` autenticado, campo `audio` com WAV | `{ "transcript": "texto reconhecido" }` |

O endpoint não interpreta intenção, não cria tarefas e não aceita `confirmation_context`. Essa responsabilidade permanece exclusivamente em `POST /v1/commands`.

## Dependências locais

- Flutter Linux: `parecord`, `pactl` e `ffmpeg` para o pacote `record`.
- Backend: `faster-whisper` com o modelo local `small`, executado em CPU com `int8`; Vosk é uma reserva para manter o serviço disponível.
- Resposta local: Piper com a voz `pt_BR-faber-medium` e `aplay`; `spd-say` é reserva se Piper não estiver disponível.

## Casos de borda

| Situação | Tratamento |
| --- | --- |
| Permissão ou dispositivo de microfone indisponível | Flutter mostra erro curto e não envia arquivo. |
| Áudio sem fala reconhecível | Flutter informa que não reconheceu a fala e não envia comando. |
| Fone P3 ou Easy Effects muda a fonte padrão | A gravação usa a fonte padrão do PipeWire; Samuel pode trocá-la nas configurações de som e tentar novamente. |
| Falha de transcrição | Não há mudança de tarefa, e o arquivo temporário é removido. |
| Fala de confirmação local diferente de `confirmo`/`enviar` ou `cancelo`/`descartar` | O Flutter mantém a transcrição pendente, explica as opções por voz e não envia comando. |
| Confirmação formal de criação pendente | `confirmo`/`cancelo` é enviado com o contexto opaco recebido da API; nunca é tratado como uma nova tarefa. |
