import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 錄音服務。
///
/// 用 WAV（PCM 16-bit）錄音，唔用 m4a：
/// m4a 嘅 "moov atom"（索引）要喺錄音完全結束時先寫入，
/// 如果檔案未寫完就上載，或者 AAC 設定唔被支援，伺服器就會讀唔到（moov atom not found）。
/// WAV 係邊錄邊寫，穩陣好多；上載後伺服器一樣會轉成 mp3。
/// 16kHz 單聲道 WAV 約 32KB/秒，1 分鐘約 1.9MB。
class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000, // 語音辨識常用 16kHz
        numChannels: 1,
      ),
      path: path,
    );
    _startedAt = DateTime.now();
  }

  /// 停止錄音。錄音太短或者檔案無效時回傳 null，並 throw [RecordingTooShort] 方便 UI 提示。
  Future<File?> stop() async {
    final path = await _recorder.stop();
    final duration = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    _startedAt = null;

    if (path == null) return null;
    final file = File(path);

    // WAV header 有 44 bytes；少過 1 秒或者冇聲音數據就當無效
    if (duration < const Duration(seconds: 1) ||
        !await file.exists() ||
        await file.length() <= 44) {
      if (await file.exists()) await file.delete();
      throw const RecordingTooShort();
    }
    return file;
  }

  Future<bool> isRecording() => _recorder.isRecording();

  void dispose() => _recorder.dispose();
}

class RecordingTooShort implements Exception {
  const RecordingTooShort();
  @override
  String toString() => '錄音太短';
}
