import Flutter
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Flutter <-> Apple Foundation Models 嘅橋樑。
/// Dart 端 channel 名：caremate/foundation_models
/// 方法：availability / respond / reset
final class FoundationModelsBridge {

  /// 保存同一個 LanguageModelSession，等 AI 記得之前講過咩（多輪對話）
  private var session: AnyObject?
  private var currentInstructions: String?

  private let defaultInstructions = """
  你係「CareMate」，一位陪伴香港長者嘅 AI 朋友。
  用對方講嘅語言回覆；講廣東話就用自然廣東話口語（繁體字）。
  每次只講 1 至 3 句，溫暖、簡單，唔好用表情符號或者列點。
  你唔係醫生，唔可以診斷，亦唔可以講任何藥物劑量。
  """

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(availabilityString())

    case "respond":
      guard let args = call.arguments as? [String: Any],
            let prompt = args["prompt"] as? String, !prompt.isEmpty else {
        result(FlutterError(code: "BAD_ARGS", message: "缺少 prompt", details: nil))
        return
      }
      let instructions = args["instructions"] as? String
      Task { await self.respond(prompt: prompt, instructions: instructions, result: result) }

    case "reset":
      session = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 檢查模型可唔可以用

  private func availabilityString() -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      switch SystemLanguageModel.default.availability {
      case .available:
        return "available"
      case .unavailable(.deviceNotEligible):
        return "deviceNotEligible"            // 部機唔支援 Apple Intelligence
      case .unavailable(.appleIntelligenceNotEnabled):
        return "appleIntelligenceNotEnabled"  // 未喺設定開 Apple Intelligence
      case .unavailable(.modelNotReady):
        return "modelNotReady"                // 模型下載緊
      case .unavailable(_):
        return "unavailable"
      }
    }
    #endif
    return "unsupportedOS"
  }

  // MARK: - 生成回覆

  private func respond(prompt: String, instructions: String?, result: @escaping FlutterResult) async {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      guard case .available = SystemLanguageModel.default.availability else {
        await reply(result, FlutterError(code: "UNAVAILABLE", message: availabilityString(), details: nil))
        return
      }

      // instructions 改變咗就開新 session
      let wanted = instructions ?? defaultInstructions
      if session == nil || currentInstructions != wanted {
        session = LanguageModelSession(instructions: wanted)
        currentInstructions = wanted
      }
      guard let s = session as? LanguageModelSession else { return }

      do {
        let response = try await s.respond(to: prompt)
        await reply(result, ["text": response.content, "tier": 1])
      } catch let error as LanguageModelSession.GenerationError {
        let code: String
        switch error {
        case .guardrailViolation:
          code = "GUARDRAIL"          // 安全機制拒答 → 之後轉 Tier 2
        case .exceededContextWindowSize:
          code = "CONTEXT_FULL"       // 對話太長 → 開新 session
          session = nil
        default:
          code = "GENERATION_ERROR"
        }
        await reply(result, FlutterError(code: code, message: Self.describe(error), details: nil))
      } catch {
        await reply(result, FlutterError(code: "UNKNOWN", message: Self.describe(error), details: nil))
      }
      return
    }
    #endif
    await reply(result, FlutterError(code: "UNAVAILABLE", message: "unsupportedOS", details: nil))
  }

  /// 將錯誤完整轉成文字（類型、domain、code、內容），方便 debug
  private static func describe(_ error: Error) -> String {
    let ns = error as NSError
    let text = "\(type(of: error)) [\(ns.domain) \(ns.code)] \(String(describing: error))"
    NSLog("%@", "[FoundationModelsBridge] \(text)")
    return text
  }

  /// FlutterResult 一定要喺 main thread 回傳
  @MainActor
  private func reply(_ result: FlutterResult, _ value: Any?) {
    result(value)
  }
}
