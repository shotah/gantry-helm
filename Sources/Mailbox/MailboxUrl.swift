import Foundation

/// Crane slug: letter first, then letters, digits, hyphen. Max 32.
private let slugRegex = try! NSRegularExpression(pattern: "^[a-z][a-z0-9-]{0,31}$")

public func parseSlug(_ raw: String) -> String? {
  let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  let range = NSRange(s.startIndex..<s.endIndex, in: s)
  guard slugRegex.firstMatch(in: s, range: range) != nil else {
    return nil
  }
  return s
}

/// Phone socket URL. Creds stay on `Authorization` (session JWE or spike
/// secret) — production handshake ignores `?secret=` / `?bearer=`.
public func mailboxUrl(_ origin: String, slug: String, role: String = "phone") -> String {
  let base = origin.trimmingCharacters(in: .whitespacesAndNewlines).trimmingSuffix("/")
  let host: String
  if base.lowercased().hasPrefix("https://") {
    host = "wss://" + String(base.dropFirst(8))
  } else if base.lowercased().hasPrefix("http://") {
    host = "ws://" + String(base.dropFirst(7))
  } else {
    host = "wss://\(base)"
  }
  return "\(host)/ws/\(slug)?role=\(role)"
}

public func httpOrigin(_ origin: String) -> String {
  origin.trimmingCharacters(in: .whitespacesAndNewlines).trimmingSuffix("/")
}

/// Operator paste → HTTP origin. Accepts the crane's `PENDANT_MAILBOX_URL`
/// (`wss://host/ws/kit`) and a bare Worker host.
public func normalizeMailboxOrigin(_ raw: String) -> String {
  let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingSuffix("/")
  if s.isEmpty {
    return s
  }
  let pattern = "^(wss?|https?)://([^/]+)(/.*)?$"
  let re = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
  let range = NSRange(s.startIndex..<s.endIndex, in: s)
  if let m = re.firstMatch(in: s, range: range), m.numberOfRanges >= 3,
    let schemeRange = Range(m.range(at: 1), in: s),
    let hostRange = Range(m.range(at: 2), in: s)
  {
    let scheme = s[schemeRange].lowercased()
    let host = String(s[hostRange])
    let path: String
    if m.numberOfRanges >= 4, let pathRange = Range(m.range(at: 3), in: s) {
      path = String(s[pathRange])
    } else {
      path = ""
    }
    let http = (scheme == "https" || scheme == "wss") ? "https" : "http"
    if path.isEmpty || path == "/" || path.lowercased().hasPrefix("/ws") {
      return "\(http)://\(host)"
    }
    return "\(http)://\(host)\(path)".trimmingSuffix("/")
  }
  return "https://\(s)"
}

extension String {
  fileprivate func trimmingSuffix(_ suffix: Character) -> String {
    var s = self
    while s.last == suffix {
      s.removeLast()
    }
    return s
  }
}
