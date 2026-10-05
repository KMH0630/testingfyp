import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/recorder_service.dart';
import 'settings_screen.dart';

/// 主畫面：只有一個大錄音按鈕。
/// 撳一下開始錄音（上方顯示 Recording），再撳一下停止並上載（上方顯示 Responding）。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _rec = RecorderService();

  bool _recording = false;
  bool _responding = false;

  @override
  void dispose() {
    _rec.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_responding) return;

    if (_recording) {
      final file = await _rec.stop();
      setState(() => _recording = false);
      if (file != null) await _upload(file);
      return;
    }

    if (!await _rec.hasPermission()) {
      _showMessage('請喺「設定」開啟咪高峰權限');
      return;
    }
    await _rec.start();
    setState(() => _recording = true);
  }

  Future<void> _upload(File file) async {
    setState(() => _responding = true);
    try {
      await _api.uploadAudio(file, source: 'record');
    } catch (e) {
      _showMessage('上載失敗，請再試一次');
      debugPrint('upload error: $e');
    } finally {
      if (mounted) setState(() => _responding = false);
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
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
