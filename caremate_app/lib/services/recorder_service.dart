import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 錄音服務。iOS 唔支援直接錄 mp3，所以錄 m4a（AAC），上載後由伺服器轉 mp3。
class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000, // 語音辨識常用 16kHz
        numChannels: 1,
        bitRate: 64000,
      ),
      path: path,
    );
  }

  /// 停止並回傳檔案
  Future<File?> stop() async {
    final path = await _recorder.stop();
    return path == null ? null : File(path);
  }

  Future<bool> isRecording() => _recorder.isRecording();

  void dispose() => _recorder.dispose();
}
