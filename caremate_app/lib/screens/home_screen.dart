import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';
import '../services/recorder_service.dart';
import '../services/speech_service.dart';
import 'settings_screen.dart';

/// 主畫面：只有一個大錄音按鈕。
/// 撳一下開始錄音（上方顯示 Recording），再撳一下停止。
/// 停止後（上方顯示 Responding）：錄音轉文字 → Apple Foundation Model 回覆 → 讀出回覆；
/// 同時將錄音上載去後端。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _rec = RecorderService();
  final _ai = AiService();
  final _speech = SpeechService();

  bool _recording = false;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    // 確保 Firestore 有 users/{uid}（第一次開 App 會自動建立）
    _api.getMe().then(
      (me) => debugPrint('user: ${me['uid']} role=${me['role']}'),
      onError: (e) => debugPrint('getMe error: $e'),
    );
  }

  @override
  void dispose() {
    _rec.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_responding) return;
    await _speech.stopSpeaking();

    if (_recording) {
      try {
        final file = await _rec.stop();
        setState(() => _recording = false);
        if (file != null) await _respond(file);
      } on RecordingTooShort {
        setState(() => _recording = false);
        _showMessage('錄音太短，請按住講多一陣');
      }
      return;
    }

    if (!await _rec.hasPermission()) {
      _showMessage('請喺「設定」開啟咪高峰權限');
      return;
    }
    await _rec.start();
    setState(() => _recording = true);
  }

  /// 錄音完成後嘅流程
  Future<void> _respond(File file) async {
    setState(() => _responding = true);

    // 1. 上載錄音去後端（同時進行，唔使等）→ users/{uid}/audio
    final upload = _upload(file);

    try {
      // 2. 錄音 → 文字
      final userText = await _speech.transcribe(file.path);
      debugPrint('STT: $userText');
      if (userText.isEmpty) {
        _showMessage('聽唔清楚，請再講一次');
        return;
      }

      // 3. 文字 → AI 回覆
      final reply = await _ai.respond(userText, instructions: aiInstructions);
      debugPrint(
        'AI (tier ${reply.tier}${reply.fallbackReason == null ? '' : ', ${reply.fallbackReason}'}): ${reply.text}',
      );
      // 4. 讀出回覆，同時等上載完成後記錄對話（連埋錄音 id）
      final log = upload
          .then(
            (audioId) => _api.logChat(
              userText,
              reply.text,
              reply.tier,
              fallbackReason: reply.fallbackReason,
              audioId: audioId,
            ),
          )
          .catchError((Object e) => debugPrint('logChat error: $e'));
      await _speech.speak(reply.text);
      await log;
    } on PlatformException catch (e) {
      debugPrint('speech error: ${e.code} ${e.message}');
      _showMessage(
        e.code == 'SPEECH_DENIED' ? '請喺「設定」開啟語音辨識權限' : '語音辨識失敗，請再試一次',
      );
    } catch (e) {
      debugPrint('respond error: $e');
      _showMessage('出咗少少問題，請再試一次');
    } finally {
      await upload;
      // 上載同語音辨識都完成先刪走手機上嘅暫存檔
      if (await file.exists()) await file.delete();
      if (mounted) setState(() => _responding = false);
    }
  }

  /// 上載錄音，成功回傳 audio id（失敗回傳 null，唔影響對話）
  Future<String?> _upload(File file) async {
    try {
      final r = await _api.uploadAudio(file, source: 'record');
      return r['id'] as String?;
    } catch (e) {
      debugPrint('upload error: $e');
      return null;
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String get _statusText {
    if (_recording) return 'Recording';
    if (_responding) return 'Responding';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 按鈕直徑：螢幕闊度嘅 65%，最大 320
    final buttonSize = (size.width * 0.65).clamp(200.0, 320.0).toDouble();
    final color = _recording
        ? Colors.red
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            iconSize: 36,
            tooltip: '設定',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 固定高度，避免文字出現／消失時按鈕跳位
              SizedBox(
                height: 64,
                child: Text(
                  _statusText,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: buttonSize,
                height: buttonSize,
                child: ElevatedButton(
                  onPressed: _responding ? null : _toggleRecord,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    elevation: 8,
                  ),
                  child: _responding
                      ? SizedBox(
                          width: buttonSize * 0.3,
                          height: buttonSize * 0.3,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 6,
                          ),
                        )
                      : Icon(
                          _recording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: buttonSize * 0.45,
                          semanticLabel: _recording ? '停止錄音' : '開始錄音',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
