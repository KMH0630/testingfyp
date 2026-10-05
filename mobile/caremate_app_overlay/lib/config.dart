/// 後端網址：用 --dart-define 傳入，例如
/// flutter run --dart-define=API_BASE_URL=https://xxxx.trycloudflare.com
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

/// Apple Foundation Model 嘅系統指示（之後可以換成 AI/prompts/system_prompt.txt 完整版）
const String aiInstructions = '''
你係「CareMate」，一位陪伴香港長者嘅 AI 朋友。
用對方講嘅語言回覆；講廣東話就用自然廣東話口語（繁體字）。
每次只講 1 至 3 句，溫暖、簡單，唔好用表情符號或者列點。
你唔係醫生，唔可以診斷，亦唔可以講任何藥物劑量。
''';
