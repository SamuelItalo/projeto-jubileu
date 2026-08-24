# POP 04 — Acesso local e confirmação por voz

## Objetivo

Restringir o MVP local ao usuário Samuel e permitir que ações pendentes sejam confirmadas ou canceladas por uma fala explícita, sem abrir mão da segurança determinística do backend.

## Acesso local inicial

- O MVP possui um único usuário: `Samuel`.
- O acesso exige senha desde a primeira execução.
- A senha inicial é fornecida localmente em variável de ambiente exclusiva do backend e é convertida em hash forte antes de ser salva no PostgreSQL. A senha em texto puro não é persistida, enviada ao Flutter, gravada em logs nem incluída em arquivos versionados.
- Enquanto a senha ainda não for definida, testes locais podem habilitar explicitamente `APP_ALLOW_INSECURE_TEST_AUTH=true`. Esse modo só pode funcionar em desenvolvimento local, deve vir desabilitado por padrão e a aplicação deve recusar iniciá-lo em ambiente não local; produção continua exigindo `APP_INITIAL_PASSWORD`.
- A autenticação inicial é local e de sessão única. Após autenticar, a sessão permanece ativa ao reiniciar o aplicativo, até que Samuel execute logout explícito ou a sessão seja invalidada por mudança de senha futura.
- O Flutter guarda somente a credencial de sessão em armazenamento seguro do dispositivo; o backend armazena e valida o identificador ou hash correspondente. Reiniciar o aplicativo não pode apagar tarefas, intervalos, ações pendentes ou sessão válida.
- Perfis múltiplos, recuperação de senha, OAuth e acesso remoto ficam fora deste MVP.

## Confirmação e cancelamento por voz

1. Ao interpretar uma ou mais ações que exigem confirmação, o backend cria um grupo e seus registros de ações pendentes, associados ao usuário e ao `request_id` original, com expiração cinco minutos após sua criação.
2. O Flutter apresenta a mensagem de confirmação retornada pelo backend e captura a nova fala do usuário.
3. A nova fala é enviada como um novo `VoiceCommandRequest`, com as referências opacas de grupo e/ou item recebidas na resposta anterior; o backend verifica propriedade, estado e validade antes de interpretá-la exclusivamente nesse contexto.
4. Uma confirmação deve ser explícita e inequívoca, por exemplo: “confirmo”, “pode criar” ou “sim, confirmar”. Um cancelamento também deve ser explícito, por exemplo: “cancelo” ou “não”.
5. Confirmação aplica exatamente a ação ou grupo pendente; cancelamento o descarta. Nenhuma das duas reinterpreta ou amplia a intenção original. O usuário pode confirmar/cancelar o grupo inteiro ou cada item separadamente.
6. Fala ambígua, ausência de ação pendente ou mais de uma ação pendente compatível produz `needs_clarification`, sem alteração persistente.

## Invariantes

- Ações pendentes pertencem exclusivamente a Samuel e não podem ser confirmadas por outro contexto ou usuário.
- Uma ação pendente e seu grupo expiram cinco minutos após sua criação. Depois disso, confirmação ou cancelamento não executam a ação e o usuário precisa enviar um novo comando.
- A confirmação por voz não pode iniciar, pausar, retomar ou concluir tarefas sem que a ação original contenha o comando explícito correspondente.
- A resposta que pede confirmação deve incluir referência opaca da ação pendente para que o Flutter a mantenha no contexto visual, mas a autoridade de associação é sempre o servidor.
- O `confirmation_context` contém `group_id` e, opcionalmente, `action_id`. O backend aceita um contexto de grupo para resolver todas as ações pendentes do grupo, ou um contexto de item para resolver somente a ação identificada.
