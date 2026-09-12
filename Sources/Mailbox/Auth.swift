import Foundation

public struct AuthConfig: Equatable {
  public var mode: String?
  public var google: Bool

  public init(mode: String?, google: Bool) {
    self.mode = mode
    self.google = google
  }
}

public struct Me: Equatable {
  public var sub: String
  public var email: String?
  public var cranes: [String]

  public init(sub: String, email: String?, cranes: [String]) {
    self.sub = sub
    self.email = email
    self.cranes = cranes
  }
}

public struct NativeSession: Equatable {
  public var token: String
  public var sub: String
  public var email: String?
  public var exp: Int64

  public init(token: String, sub: String, email: String?, exp: Int64) {
    self.token = token
    self.sub = sub
    self.email = email
    self.exp = exp
  }
}

public struct HTTPResult {
  public var status: Int
  public var body: Data
  public var headers: [String: String]

  public init(status: Int, body: Data, headers: [String: String] = [:]) {
    self.status = status
    self.body = body
    self.headers = headers
  }
}

public protocol HTTPTransport {
  func perform(_ request: URLRequest) throws -> HTTPResult
}

public struct AuthError: Error, Equatable {
  public var code: Int
  public var body: String

  public init(code: Int, body: String) {
    self.code = code
    self.body = body
  }
}

/// Server-issued native nonce when GET `/api/auth/nonce` is missing or junk.
public func mintNonce() -> String {
  var bytes = [UInt8](repeating: 0, count: 24)
  for i in 0..<24 {
    bytes[i] = UInt8.random(in: 0...255)
  }
  return Data(bytes).base64EncodedString()
    .replacingOccurrences(of: "+", with: "-")
    .replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
}

public func parseAuthConfig(_ raw: String) -> AuthConfig {
  guard let o = JSON.object(raw) else {
    return AuthConfig(mode: nil, google: false)
  }
  return AuthConfig(mode: JSON.string(o, "mode"), google: JSON.bool(o, "google"))
}

public func parseNonce(_ raw: String) -> String? {
  JSON.object(raw).flatMap { JSON.string($0, "nonce") }
}

public func parseMe(_ raw: String) throws -> Me {
  guard let o = JSON.object(raw), let subValue = JSON.string(o, "sub") else {
    throw AuthError(code: 0, body: raw)
  }
  var cranes: [String] = []
  if let arr = o["cranes"] as? [Any] {
    for item in arr {
      guard let s = item as? String, let slug = parseSlug(s) else {
        continue
      }
      cranes.append(slug)
    }
  }
  return Me(sub: subValue, email: JSON.string(o, "email"), cranes: cranes)
}

public func parseNativeSession(_ raw: String) throws -> NativeSession {
  guard let o = JSON.object(raw),
    let token = JSON.string(o, "token"),
    let sub = JSON.string(o, "sub")
  else {
    throw AuthError(code: 0, body: raw)
  }
  let exp = jsonWholeNumber(o["exp"]) ?? 0
  return NativeSession(token: token, sub: sub, email: JSON.string(o, "email"), exp: exp)
}

public final class AuthApi {
  private let transport: HTTPTransport

  public init(transport: HTTPTransport) {
    self.transport = transport
  }

  public func config(origin: String) throws -> AuthConfig {
    let body = try get(httpOrigin(origin) + "/api/auth/config")
    return parseAuthConfig(body)
  }

  /**
   Server-issued native nonce when the Worker has `GET /api/auth/nonce`.
   Missing route, junk body, or empty value → nil so the phone can mint.
   */
  public func nonce(origin: String) -> String? {
    do {
      let body = try get(httpOrigin(origin) + "/api/auth/nonce")
      return parseNonce(body)
    } catch {
      return nil
    }
  }

  public func me(origin: String, token: String) throws -> Me {
    let body = try get(httpOrigin(origin) + "/api/auth/me", token: token)
    return try parseMe(body)
  }

  public func token(origin: String, idToken: String, nonce: String) throws -> NativeSession {
    let payload = JSON.stringify(["id_token": idToken, "nonce": nonce])
    let body = try post(httpOrigin(origin) + "/api/auth/token", json: payload)
    return try parseNativeSession(body)
  }

  private func get(_ url: String, token: String? = nil) throws -> String {
    var req = URLRequest(url: URL(string: url)!)
    req.httpMethod = "GET"
    if let token, !token.isEmpty {
      req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    return try execute(req)
  }

  private func post(_ url: String, json: String) throws -> String {
    var req = URLRequest(url: URL(string: url)!)
    req.httpMethod = "POST"
    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    req.httpBody = json.data(using: .utf8)
    return try execute(req)
  }

  private func execute(_ req: URLRequest) throws -> String {
    let res = try transport.perform(req)
    let raw = String(data: res.body, encoding: .utf8) ?? ""
    if res.status < 200 || res.status >= 300 {
      throw AuthError(code: res.status, body: raw)
    }
    return raw
  }
}

/// `{ "theme": "noir" | null, "themes": [...] }` — catalog cards are ignored.
public func roomThemeFromState(_ raw: String) -> String {
  guard let o = JSON.object(raw) else {
    return ""
  }
  if !JSON.has(o, "theme") || JSON.isNull(o, "theme") {
    return ""
  }
  return knownTheme(o["theme"] as? String) ?? ""
}

public final class ThemeApi {
  private let transport: HTTPTransport

  public init(transport: HTTPTransport) {
    self.transport = transport
  }

  /// GET `/api/theme?slug=`. Known id, empty when the room has none, nil on HTTP fail.
  public func fetch(origin: String, slug: String, bearer: String) -> String? {
    var req = URLRequest(url: URL(string: themeUrl(origin, slug: slug))!)
    req.httpMethod = "GET"
    if !bearer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }
    do {
      let res = try transport.perform(req)
      if res.status < 200 || res.status >= 300 {
        return nil
      }
      return roomThemeFromState(String(data: res.body, encoding: .utf8) ?? "")
    } catch {
      return nil
    }
  }
}
