import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum TtsResult: Equatable {
  case ok(Data)
  case err(SpeakFail)
}

public func ttsUrl(_ origin: String) -> String {
  httpOrigin(origin) + "/api/tts"
}

public final class TtsApi {
  private let transport: HTTPTransport

  public init(transport: HTTPTransport) {
    self.transport = transport
  }

  public func synthesize(origin: String, bearer: String, text: String, lang: String = defaultLang) -> TtsResult {
    let payload = JSON.stringify(["text": text, "lang": parseLang(lang)])
    var req = URLRequest(url: URL(string: ttsUrl(origin))!)
    req.httpMethod = "POST"
    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    req.httpBody = payload.data(using: .utf8)
    if !bearer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }
    do {
      let res = try transport.perform(req)
      if res.status < 200 || res.status >= 300 {
        return .err(speakFailFromStatus(res.status))
      }
      if res.body.isEmpty {
        return .err(.vendor)
      }
      return .ok(res.body)
    } catch {
      return .err(.offline)
    }
  }
}
