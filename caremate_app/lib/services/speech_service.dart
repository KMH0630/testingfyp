import 'package:flutter/services.dart';

/// 透過 MethodChannel 呼叫 iOS 原生語音功能（SpeechBridge.swift）。
class SpeechService {
  static const _channel = MethodChannel('caremate/speech');
  static const defaultLocale = 'zh-HK'; // 廣東話（香港）

  /// 錄音檔轉文字。冇聽到講嘢就回傳空字串。
  /// 失敗會 throw PlatformException（SPEECH_DENIED / SPEECH_UNAVAILABLE / SPEECH_ERROR）。
  Future<String> transcribe(String path, {String locale = defaultLocale}) async {
    final text = await _channel.invokeMethod<String>('transcribe', {
      'path': path,
      'locale': locale,
    });
    return (text ?? '').trim();
  }

  /// 讀出文字，讀完先完成。
  Future<void> speak(String text, {String locale = defaultLocale}) async {
    try {
      await _channel.invokeMethod('speak', {'text': text, 'locale': locale});
    } on MissingPluginException {
      // Android 暫時未有
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _channel.invokeMethod('stopSpeaking');
    } on MissingPluginException {
      // ignore
    }
  }
}
