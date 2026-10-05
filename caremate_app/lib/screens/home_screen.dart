import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';

import '../config.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';
import '../services/recorder_service.dart';

/// 原型主畫面：(1) 測試連線 (2) 同 Apple Foundation Model 傾偈 (3) 錄音上載
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ai = AiService();
  final _api = ApiService();
  final _rec = RecorderService();
  final _input = TextEditingController();

  String _aiStatus = '檢查中…';
  String _serverStatus = '未測試';
  String _reply = '';
  String _uploadResult = '';
  bool _thinking = false;
  bool _recording = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _ai.availability().then((s) => setState(() => _aiStatus = s));
  }

  @override
  void dispose() {
    _rec.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _testServer() async {
    try {
      final r = await _api.health();
      setState(() => _serverStatus = '連線成功：$r');
    } catch (e) {
      setState(() => _serverStatus = '連唔到 $apiBaseUrl：$e');
    }
  }

  Future<void> _ask() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _thinking = true);
    final reply = await _ai.respond(text, instructions: aiInstructions);
    setState(() {
      _reply = reply.text;
      _thinking = false;
    });
    // 記錄去後端（失敗唔影響使用）
    _api
        .logChat(text, reply.text, reply.tier, fallbackReason: reply.fallbackReason)
        .catchError((_) {});
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final file = await _rec.stop();
      setState(() => _recording = false);
      if (file != null) await _upload(file, 'record');
    } else {
      if (!await _rec.hasPermission()) {
        setState(() => _uploadResult = '請喺「設定」開啟咪高峰權限');
        return;
      }
      await _rec.start();
      setState(() => _recording = true);
    }
  }
  Future<void> _pickMp3() async {
    // file_picker 12+：pickFile() 回傳單一檔案，撳取消時回傳 null
    final file = await fp.FilePicker.pickFile(
      type: fp.FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav'],
    );
    final path = file?.path;
    if (path != null) await _upload(File(path), 'file');
  }

  Future<void> _upload(File file, String source) async {
    setState(() {
      _uploading = true;
      _uploadResult = '上載中…';
    });
    try {
      final r = await _api.uploadAudio(file, source: source);
      setState(() => _uploadResult =
          '成功！\nID：${r['id']}\n長度：${r['duration_sec']} 秒\n大小：${r['size_bytes']} bytes\nFirestore：${r['saved_to_firestore']}');
    } catch (e) {
      setState(() => _uploadResult = '失敗：$e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final big = const Size.fromHeight(72); // 長者友善：大按鈕
    return Scaffold(
      appBar: AppBar(title: const Text('CareMate 原型')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('AI 狀態：$_aiStatus'),
            const SizedBox(height: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: big),
              onPressed: _testServer,
              child: const Text('測試伺服器連線'),
            ),
            Text(_serverStatus),
            const Divider(height: 40),

            // ===== 1. Foundation Model 對話 =====
            TextField(
              controller: _input,
              decoration: const InputDecoration(
                labelText: '想同 CareMate 講咩？',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: big),
              onPressed: _thinking ? null : _ask,
              child: Text(_thinking ? '諗緊…' : '傳送'),
            ),
            const SizedBox(height: 12),
            if (_reply.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_reply),
                ),
              ),
            TextButton(onPressed: _ai.reset, child: const Text('開新話題')),
            const Divider(height: 40),

            // ===== 2. 錄音上載 =====
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(96),
                backgroundColor: _recording ? Colors.red : null,
              ),
              onPressed: _uploading ? null : _toggleRecord,
              icon: Icon(_recording ? Icons.stop : Icons.mic, size: 40),
              label: Text(_recording ? '停止並上載' : '開始錄音'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: big),
              onPressed: _uploading ? null : _pickMp3,
              child: const Text('揀手機入面嘅 mp3 上載'),
            ),
            const SizedBox(height: 12),
            Text(_uploadResult),
          ],
        ),
      ),
    );
  }
}
