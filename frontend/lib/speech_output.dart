import 'dart:io';

/// Saída de voz local do Jubileu para o desktop Linux.
///
/// O Piper é priorizado para produzir fala neural em pt-BR. O Speech Dispatcher
/// permanece como reserva. Nenhum texto é enviado para serviços externos, e
/// uma falha na fala não interfere no fluxo de tarefas.
class SpeechOutput {
  static const _voiceFile = 'pt_BR-faber-medium.onnx';
  Future<void> _queue = Future.value();

  Future<void> speak(String text) async {
    final message = text.trim();
    if (!Platform.isLinux || message.isEmpty) return;

    _queue = _queue.then((_) => _speak(message)).catchError((_) {});
    await _queue;
  }

  Future<void> _speak(String message) async {
    final piper = await _findPiper();
    if (piper != null) {
      try {
        await _speakWithPiper(message, piper);
        return;
      } on ProcessException {
        // A reserva abaixo mantém a resposta por voz disponível.
      }
    }

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

  Future<_PiperSetup?> _findPiper() async {
    final candidates = <Directory>[Directory.current, Directory.current.parent];
    for (final root in candidates) {
      final executable = File('${root.path}/.venv/bin/piper');
      final model = File('${root.path}/models/piper/$_voiceFile');
      if (await executable.exists() && await model.exists()) {
        return _PiperSetup(executable.path, model.path, root.path);
      }
    }
    return null;
  }

  Future<void> _speakWithPiper(String message, _PiperSetup piper) async {
    final temporaryDirectory = Directory('${piper.projectRoot}/.tmp');
    await temporaryDirectory.create(recursive: true);
    final wav = File(
      '${temporaryDirectory.path}/piper-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    try {
      final process = await Process.start(piper.executable, [
        '--model',
        piper.model,
        '--output-file',
        wav.path,
        '--length-scale',
        '1.06',
      ]);
      process.stdin.write(message);
      await process.stdin.close();
      if (await process.exitCode != 0 || !await wav.exists()) {
        throw const ProcessException(
          'piper',
          [],
          'Não foi possível gerar a fala.',
        );
      }
      final playback = await Process.run('aplay', ['-q', wav.path]);
      if (playback.exitCode != 0) {
        throw ProcessException('aplay', [], playback.stderr.toString());
      }
    } finally {
      if (await wav.exists()) await wav.delete();
    }
  }
}

class _PiperSetup {
  const _PiperSetup(this.executable, this.model, this.projectRoot);

  final String executable;
  final String model;
  final String projectRoot;
}
