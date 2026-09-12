/// Same ids as pendant `lib/theme/catalog.ts`. Boom / Inlay / Lamp hexes must not drift.
public let themeIds = [
  "boom",
  "inlay",
  "lamp",
  "noir",
  "ember",
  "tide",
  "bloom",
  "paper",
  "chalk",
  "foam",
  "petal",
  "ink",
]
public let defaultTheme = "boom"

public let fontIds = ["sm", "md", "lg", "xl"]
public let defaultFont = "sm"

public func knownTheme(_ v: String?) -> String? {
  guard let v, themeIds.contains(v) else {
    return nil
  }
  return v
}

public func parseTheme(_ v: String?) -> String {
  knownTheme(v) ?? defaultTheme
}

public func parseFont(_ v: String?) -> String {
  guard let v, fontIds.contains(v) else {
    return defaultFont
  }
  return v
}

public func chatSp(_ fontId: String) -> Float {
  switch parseFont(fontId) {
  case "md": return 16
  case "lg": return 20
  case "xl": return 24
  default: return 14
  }
}

public func themeLabel(_ id: String) -> String {
  let t = parseTheme(id)
  guard let first = t.first else {
    return t
  }
  return String(first).uppercased() + t.dropFirst()
}

public func fontLabel(_ id: String) -> String {
  switch parseFont(id) {
  case "md": return "Medium"
  case "lg": return "Large"
  case "xl": return "Extra large"
  default: return "Small"
  }
}

/// What to paint. Follow Kit when the room has a known id; empty / junk / follow-off
/// keeps the human's pick. Same rule as pendant `THEME_BOOT`.
public func paintedTheme(follow: Bool, roomTheme: String, mine: String) -> String {
  if !follow {
    return parseTheme(mine)
  }
  return knownTheme(roomTheme) ?? parseTheme(mine)
}
