import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/emergency_contact.dart';
import '../models/medication.dart';

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

  /// 上載音訊（wav / m4a / mp3），伺服器會統一轉成 mp3，並記錄去 users/{uid}/audio/{id}
  Future<Map<String, dynamic>> uploadAudio(
    File file, {
    String source = 'record',
  }) async {
    final req =
        http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/audio/upload'))
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

  /// 讀取（第一次會自動建立）自己嘅用戶資料 users/{uid}
  Future<Map<String, dynamic>> getMe() async {
    final res = await http
        .get(Uri.parse('$apiBaseUrl/users/me'), headers: await _authHeader())
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('讀取用戶資料失敗 (${res.statusCode})：${res.body}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// 將一輪對話記錄去 users/{uid}/messages；audioId 對應 users/{uid}/audio/{audioId}
  Future<void> logChat(
    String userText,
    String aiText,
    int tier, {
    String? fallbackReason,
    String? audioId,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBaseUrl/chat/log'),
          headers: {...await _authHeader(), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_text': userText,
            'ai_text': aiText,
            'model_tier': tier,
            'fallback_reason': fallbackReason,
            'audio_id': audioId,
            'input_type': 'voice',
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('記錄對話失敗 (${res.statusCode})：${res.body}');
    }
  }

  // ---------- 共用 ----------

  Future<Map<String, String>> _jsonHeader() async => {
    ...await _authHeader(),
    'Content-Type': 'application/json',
  };

  dynamic _decode(http.Response res, String action) {
    if (res.statusCode != 200) {
      throw HttpException('$action failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  // ---------- 藥物：users/{uid}/medications ----------

  Future<List<Medication>> listMedications() async {
    final res = await http
        .get(Uri.parse('$apiBaseUrl/medications'), headers: await _authHeader())
        .timeout(const Duration(seconds: 15));
    final list = _decode(res, 'Load medications') as List<dynamic>;
    return list
        .map((e) => Medication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Medication> saveMedication(Medication med) async {
    final uri = med.id == null
        ? Uri.parse('$apiBaseUrl/medications')
        : Uri.parse('$apiBaseUrl/medications/${med.id}');
    final body = jsonEncode(med.toJson());
    final headers = await _jsonHeader();
    final res =
        await (med.id == null
                ? http.post(uri, headers: headers, body: body)
                : http.put(uri, headers: headers, body: body))
            .timeout(const Duration(seconds: 15));
    return Medication.fromJson(
      _decode(res, 'Save medication') as Map<String, dynamic>,
    );
  }

  Future<void> deleteMedication(String id) async {
    final res = await http
        .delete(
          Uri.parse('$apiBaseUrl/medications/$id'),
          headers: await _authHeader(),
        )
        .timeout(const Duration(seconds: 15));
    _decode(res, 'Delete medication');
  }

  // ---------- 緊急聯絡人：users/{uid}.emergency_contacts ----------

  Future<List<EmergencyContact>> listContacts() async {
    final me = await getMe();
    final list = me['emergency_contacts'] as List<dynamic>? ?? [];
    return list
        .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 成個名單一次過儲存（最多 5 個）
  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final res = await http
        .put(
          Uri.parse('$apiBaseUrl/users/me'),
          headers: await _jsonHeader(),
          body: jsonEncode({
            'emergency_contacts': contacts.map((c) => c.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    _decode(res, 'Save contacts');
  }
}
