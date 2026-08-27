import 'dart:io';

/// Saída de voz local do Jubileu para o desktop Linux.
///
/// O Speech Dispatcher é chamado diretamente pelo sistema operacional. Nenhum
/// texto é enviado para serviços externos, e uma falha na fala não interfere
/// no fluxo de tarefas.
class SpeechOutput {
  Future<void> speak(String text) async {
    final message = text.trim();
    if (!Platform.isLinux || message.isEmpty) return;

    try {
      await Process.run('spd-say', [
        '--application-name',
        'Jubileu',
        '--language',
        'pt-BR',
        '--rate',
        '-10',
        '--priority',
        'notification',
        message,
      ]);
    } on ProcessException {
      // A voz é complementar: o retorno visual continua sendo a fonte segura.
    }
  }
}
