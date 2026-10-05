import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// 同 FastAPI 後端溝通。每個 request 都帶 Firebase ID token，後端用嚟確認身份。
class ApiService {
  Future<Map<String, String>> _authHeader() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> health() async {
    final res = await http
        .get(Uri.parse('$apiBaseUrl/health'))
        .timeout(const Duration(seconds: 8));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// 上載音訊（m4a / mp3 / wav），伺服器會統一轉成 mp3
  Future<Map<String, dynamic>> uploadAudio(File file, {String source = 'record'}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/audio/upload'))
      ..headers.addAll(await _authHeader())
      ..fields['source'] = source
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw HttpException('上載失敗 (${streamed.statusCode})：$body');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// 將一次 AI 對話記錄傳去後端（後端寫入 Firestore）
  Future<void> logChat(String userText, String aiText, int tier, {String? fallbackReason}) async {
    await http.post(
      Uri.parse('$apiBaseUrl/chat/log'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_text': userText,
        'ai_text': aiText,
        'model_tier': tier,
        'fallback_reason': fallbackReason,
      }),
    );
  }
}
