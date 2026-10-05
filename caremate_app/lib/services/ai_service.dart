import 'package:flutter/services.dart';

/// AI 回覆結果。tier：1 = Apple Foundation Model；0 = 預設安全回覆（之後會加 2 = 自訓模型）
class AiReply {
  final String text;
  final int tier;
  final String? fallbackReason;
  const AiReply(this.text, this.tier, {this.fallbackReason});
}

/// 透過 MethodChannel 呼叫 iOS 原生嘅 Foundation Models（Swift）。
class AiService {
  static const _channel = MethodChannel('caremate/foundation_models');

  /// 回傳 available / deviceNotEligible / appleIntelligenceNotEnabled / modelNotReady / unsupportedOS / notIOS
  Future<String> availability() async {
    try {
      return await _channel.invokeMethod<String>('availability') ?? 'unknown';
    } on MissingPluginException {
      return 'notIOS'; // Android 冇呢個 channel
    }
  }

  Future<AiReply> respond(String prompt, {String? instructions}) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('respond', {
        'prompt': prompt,
        if (instructions != null) 'instructions': instructions,
      });
      return AiReply(res?['text'] as String? ?? '', 1);
    } on PlatformException catch (e) {
      // GUARDRAIL / CONTEXT_FULL / UNAVAILABLE / GENERATION_ERROR
      // 之後喺呢度轉去 Tier 2 自訓模型
      return AiReply('唔好意思，我而家諗唔到點答，不如我哋傾下第樣嘢？', 0,
          fallbackReason: e.code);
    } on MissingPluginException {
      return const AiReply('呢部手機未支援 AI 對話功能。', 0, fallbackReason: 'notIOS');
    }
  }

  /// 開新話題（清空對話記憶）
  Future<void> reset() async {
    try {
      await _channel.invokeMethod('reset');
    } on MissingPluginException {
      // ignore
    }
  }
}
