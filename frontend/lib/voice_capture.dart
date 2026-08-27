import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api_client.dart';

class VoiceCapture {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;

  bool get isRecording => _recording;

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw const ApiException('Não foi possível acessar o microfone.');
    }
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/jubileu-${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _recording = true;
  }

  Future<String> stopAndTranscribe(ApiClient api) async {
    final path = await _recorder.stop();
    _recording = false;
    if (path == null) {
      throw const ApiException(
        'A gravação não foi concluída. Tente novamente.',
      );
    }
    final audio = File(path);
    try {
      return await api.transcribe(audio);
    } finally {
      if (await audio.exists()) await audio.delete();
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
