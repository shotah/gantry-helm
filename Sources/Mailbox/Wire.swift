import Foundation

public struct Geo: Equatable {
  public var lat: Double
  public var lon: Double
  public var accuracyM: Double?
  public var altM: Double?
  public var heading: Double?
  public var speedMps: Double?

  public init(
    lat: Double,
    lon: Double,
    accuracyM: Double? = nil,
    altM: Double? = nil,
    heading: Double? = nil,
    speedMps: Double? = nil
  ) {
    self.lat = lat
    self.lon = lon
    self.accuracyM = accuracyM
    self.altM = altM
    self.heading = heading
    self.speedMps = speedMps
  }
}

public struct BatteryHint: Equatable {
  public var pct: Int
  public var charging: Bool

  public init(pct: Int, charging: Bool) {
    self.pct = pct
    self.charging = charging
  }
}

public struct PhoneContext: Equatable {
  public var at: String?
  public var tz: String?
  public var geo: Geo?
  public var battery: BatteryHint?
  public var net: String?
  public var surface: String?

  public init(
    at: String? = nil,
    tz: String? = nil,
    geo: Geo? = nil,
    battery: BatteryHint? = nil,
    net: String? = nil,
    surface: String? = nil
  ) {
    self.at = at
    self.tz = tz
    self.geo = geo
    self.battery = battery
    self.net = net
    self.surface = surface
  }
}

public struct WireFrame: Equatable {
  public var text: String?
  public var kind: String?
  public var id: String?
  public var since: String?
  public var images: [String]?
  public var context: PhoneContext?
  public var commands: [SlashCommand]?
  public var seq: Int?
  public var at: Int64?
  public var replay: Bool
  /// Backdrop notice only. 0 = cleared.
  public var rev: Int?
  /// Theme notice only. Empty = cleared.
  public var theme: String?

  public init(
    kind: String? = nil,
    text: String? = nil,
    id: String? = nil,
    since: String? = nil,
    images: [String]? = nil,
    context: PhoneContext? = nil,
    commands: [SlashCommand]? = nil,
    seq: Int? = nil,
    at: Int64? = nil,
    replay: Bool = false,
    rev: Int? = nil,
    theme: String? = nil
  ) {
    self.kind = kind
    self.text = text
    self.id = id
    self.since = since
    self.images = images
    self.context = context
    self.commands = commands
    self.seq = seq
    self.at = at
    self.replay = replay
    self.rev = rev
    self.theme = theme
  }
}

public let textBytesMax = 8_000
public let textCharsMax = textBytesMax

public func encodeFrame(_ frame: WireFrame) -> String {
  var o: [String: Any] = [:]
  if let text = frame.text {
    o["text"] = text
  }
  if let kind = frame.kind {
    o["kind"] = kind
  }
  if let id = frame.id {
    o["id"] = id
  }
  if let since = frame.since {
    o["since"] = since
  }
  if let urls = frame.images, !urls.isEmpty {
    o["images"] = urls.map { ["url": $0] }
  }
  if let ctx = frame.context {
    var c: [String: Any] = [:]
    if let at = ctx.at {
      c["at"] = at
    }
    if let tz = ctx.tz {
      c["tz"] = tz
    }
    if let g = ctx.geo {
      var geo: [String: Any] = ["lat": g.lat, "lon": g.lon]
      if let v = g.accuracyM {
        geo["accuracy_m"] = v
      }
      if let v = g.altM {
        geo["alt_m"] = v
      }
      if let v = g.heading {
        geo["heading"] = v
      }
      if let v = g.speedMps {
        geo["speed_mps"] = v
      }
      c["geo"] = geo
    }
    if let b = ctx.battery {
      c["battery"] = ["pct": b.pct, "charging": b.charging]
    }
    if let net = netOnWire(ctx.net) {
      c["net"] = net
    }
    if let surface = surfaceOnWire(ctx.surface) {
      c["surface"] = surface
    }
    if !c.isEmpty {
      o["context"] = c
    }
  }
  return JSON.stringify(o)
}

public func parseFrame(_ raw: String) -> WireFrame? {
  if raw == "ping" || raw == "pong" {
    return nil
  }
  guard let o = JSON.object(raw) else {
    return nil
  }
  let kind = JSON.string(o, "kind")
  var images: [String]?
  if let arr = JSON.array(o["images"]) {
    var urls: [String] = []
    for item in arr {
      let url = (JSON.dict(item)?["url"] as? String) ?? ""
      if acceptInboundImage(url) {
        urls.append(url)
      }
    }
    if !urls.isEmpty {
      images = urls
    }
  }
  return WireFrame(
    kind: kind,
    text: capWireText(JSON.string(o, "text")),
    id: JSON.string(o, "id"),
    since: JSON.string(o, "since"),
    images: images,
    commands: kind == "cmds" ? parseCommands(o["commands"]) : nil,
    seq: orderSeq(o["seq"]),
    at: orderAt(o["at"]),
    replay: JSON.bool(o, "replay"),
    rev: backdropRev(kind, o["rev"]),
    theme: roomThemeNotice(
      kind,
      themePresent: JSON.has(o, "theme"),
      themeNull: JSON.isNull(o, "theme"),
      themeRaw: o["theme"] as? String
    )
  )
}

public func inbound(
  _ text: String,
  id: String,
  context: PhoneContext?,
  images: [String]? = nil
) -> WireFrame {
  let speech = stripHarnessContext(text)
  return WireFrame(
    kind: "inbound",
    text: capWireText(speech.isEmpty ? nil : speech),
    id: id,
    images: images.flatMap { $0.isEmpty ? nil : $0 },
    context: context
  )
}

public func pinFrame(_ context: PhoneContext) -> WireFrame {
  WireFrame(kind: "pin", context: context)
}

public func ackSince(_ since: String) -> WireFrame {
  WireFrame(kind: "ack", since: since)
}

/// Mailbox sequence; 1-based. Ignore junk so an old client cannot poison a frame.
public func orderSeq(_ raw: Any?) -> Int? {
  guard let n = jsonWholeNumber(raw) else {
    return nil
  }
  if n < 1 || n > Int64(Int.max) {
    return nil
  }
  return Int(n)
}

/// Epoch ms when the mailbox accepted the frame.
public func orderAt(_ raw: Any?) -> Int64? {
  guard let n = jsonWholeNumber(raw) else {
    return nil
  }
  return n >= 0 ? n : nil
}

public func shouldSpeak(_ kind: String?, replay: Bool = false) -> Bool {
  !replay && (kind == "reply" || kind == "push")
}

public func capWireText(_ text: String?) -> String? {
  guard let t = text else {
    return nil
  }
  return capUtf8(t, maxBytes: textBytesMax)
}

public func capUtf8(_ text: String, maxBytes: Int = textBytesMax) -> String {
  let bytes = Array(text.utf8)
  if bytes.count <= maxBytes {
    return text
  }
  var n = maxBytes
  while n > 0 && n < bytes.count && (bytes[n] & 0xC0) == 0x80 {
    n -= 1
  }
  return String(decoding: bytes[0..<n], as: UTF8.self)
}

public func acceptInboundImage(_ url: String) -> Bool {
  if url.isEmpty {
    return false
  }
  if url.hasPrefix("data:image/") {
    return decodeDataUrl(url) != nil
  }
  return url.hasPrefix("https://") && url.count <= 2_048
}

public func netOnWire(_ net: String?) -> String? {
  guard let net, net == "wifi" || net == "cellular" || net == "unknown" else {
    return nil
  }
  return net
}

/// Mailbox `Surface` plus Helm. Unknown names are dropped (Cab's `pendant` is too).
public func surfaceOnWire(_ surface: String?) -> String? {
  switch surface {
  case "browser", "android", "android_auto", "ios", "carplay":
    return surface
  default:
    return nil
  }
}

public func surfaceHint(carAttached: Bool) -> String {
  carAttached ? "carplay" : "ios"
}

public func batteryHint(pct: Int, charging: Bool) -> BatteryHint? {
  guard (0...100).contains(pct) else {
    return nil
  }
  return BatteryHint(pct: pct, charging: charging)
}

/// `UIDevice.batteryLevel` is 0...1, or negative if unknown.
public func batteryHintFromLevel(_ level: Float, charging: Bool) -> BatteryHint? {
  if level < 0 {
    return nil
  }
  return batteryHint(pct: Int((level * 100).rounded()), charging: charging)
}

public func netHint(wifi: Bool, cellular: Bool) -> String {
  if wifi {
    return "wifi"
  }
  if cellular {
    return "cellular"
  }
  return "unknown"
}

public func notifyBody(_ text: String?, hasPhoto: Bool) -> String {
  let t = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  if !t.isEmpty {
    return t
  }
  return hasPhoto ? "Photo" : "ping"
}
