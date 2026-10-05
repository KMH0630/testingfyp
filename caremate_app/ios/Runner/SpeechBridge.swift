import AVFoundation
import Flutter
import Speech

/// Flutter <-> iOS 語音功能嘅橋樑。
/// Dart 端 channel 名：caremate/speech
/// 方法：
///   transcribe {path, locale}  → 錄音檔轉文字（Speech-to-Text，SFSpeechRecognizer）
///   speak      {text, locale}  → 讀出文字（Text-to-Speech，AVSpeechSynthesizer），讀完先回傳
///   stopSpeaking               → 即刻停止讀
final class SpeechBridge: NSObject, AVSpeechSynthesizerDelegate {

  private let synthesizer = AVSpeechSynthesizer()
  private var currentUtterance: AVSpeechUtterance?
  private var speakResult: FlutterResult?
  private var recognitionTask: SFSpeechRecognitionTask?

  override init() {
    super.init()
    synthesizer.delegate = self
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let locale = args["locale"] as? String ?? "zh-HK"

    switch call.method {
    case "transcribe":
      guard let path = args["path"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "缺少 path", details: nil))
        return
      }
      transcribe(url: URL(fileURLWithPath: path), locale: locale, result: result)

    case "speak":
      guard let text = args["text"] as? String, !text.isEmpty else {
        result(nil)
        return
      }
      speak(text, locale: locale, result: result)

    case "stopSpeaking":
      synthesizer.stopSpeaking(at: .immediate)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Speech-to-Text

  private func transcribe(url: URL, locale: String, result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        guard status == .authorized else {
          result(FlutterError(code: "SPEECH_DENIED", message: "未允許語音辨識", details: nil))
          return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
              recognizer.isAvailable else {
          result(FlutterError(code: "SPEECH_UNAVAILABLE", message: "\(locale) 語音辨識暫時用唔到", details: nil))
          return
        }

        // 部機支援就先試喺手機本身辨識（錄音唔會傳去 Apple 伺服器）；
        // 如果手機未下載廣東話離線模型，會出 kLSRErrorDomain 300「Failed to initialize recognizer」，
        // 咁就自動改用網絡辨識再試一次。
        let preferOnDevice = recognizer.supportsOnDeviceRecognition
        self.recognize(url: url, recognizer: recognizer, onDevice: preferOnDevice) { text, error in
          if let ns = error as NSError?, preferOnDevice, ns.domain == "kLSRErrorDomain" {
            NSLog("%@", "[SpeechBridge] on-device 辨識失敗（\(ns.domain) \(ns.code)），改用網絡辨識")
            self.recognize(url: url, recognizer: recognizer, onDevice: false) { text2, error2 in
              self.finish(result, text: text2, error: error2)
            }
          } else {
            self.finish(result, text: text, error: error)
          }
        }
      }
    }
  }

  /// 執行一次辨識，完成時喺 main thread 回傳 (文字, 錯誤)
  private func recognize(url: URL, recognizer: SFSpeechRecognizer, onDevice: Bool,
                         completion: @escaping (String?, Error?) -> Void) {
    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false
    request.addsPunctuation = true
    request.requiresOnDeviceRecognition = onDevice

    var finished = false
    recognitionTask = recognizer.recognitionTask(with: request) { res, error in
      DispatchQueue.main.async {
        if finished { return }
        if let res = res, res.isFinal {
          finished = true
          completion(res.bestTranscription.formattedString, nil)
        } else if let error = error {
          finished = true
          completion(nil, error)
        }
      }
    }
  }

  private func finish(_ result: FlutterResult, text: String?, error: Error?) {
    if let text = text {
      result(text)
      return
    }
    guard let ns = error as NSError? else {
      result("")
      return
    }
    // 1110 = 冇偵測到講嘢 → 當空白
    if ns.domain == "kAFAssistantErrorDomain" && ns.code == 1110 {
      result("")
    } else {
      result(FlutterError(code: "SPEECH_ERROR",
                          message: "\(ns.domain) \(ns.code): \(ns.localizedDescription)",
                          details: nil))
    }
  }

  // MARK: - Text-to-Speech

  private func speak(_ text: String, locale: String, result: @escaping FlutterResult) {
    // 如果之前仲讀緊，先完成舊嘅 result 再停
    completeSpeaking()
    if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }

    // 錄音之後 audio session 可能仲係錄音模式，要轉返播放模式，否則會好細聲或者冇聲
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    try? session.setActive(true)

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: locale)
      ?? AVSpeechSynthesisVoice(language: "zh-HK")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9   // 慢少少，長者易聽

    currentUtterance = utterance
    speakResult = result
    synthesizer.speak(utterance)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    if utterance === currentUtterance { completeSpeaking() }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    if utterance === currentUtterance { completeSpeaking() }
  }

  private func completeSpeaking() {
    guard let r = speakResult else { return }
    speakResult = nil
    currentUtterance = nil
    DispatchQueue.main.async { r(nil) }
  }
}
