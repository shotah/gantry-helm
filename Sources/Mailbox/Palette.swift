/// Boom / Inlay / Lamp hexes must not drift from pendant `lib/theme/catalog.ts` / Cab `CabPalette`.
/// Values are 0xRRGGBB (opaque). SwiftUI maps them in the app target.
public struct HelmColors: Equatable {
  public var canvas: UInt32
  public var panel: UInt32
  public var track: UInt32
  public var line: UInt32
  public var edge: UInt32
  public var fg: UInt32
  public var body: UInt32
  public var muted: UInt32
  public var dim: UInt32
  public var accent: UInt32
  public var mark: UInt32
  public var accentLine: UInt32
  public var accentSoft: UInt32
  public var danger: UInt32
  public var ok: UInt32
  public var you: UInt32
  public var kit: UInt32
  public var scheme: String
}

public func helmColors(_ themeId: String) -> HelmColors {
  switch parseTheme(themeId) {
  case "inlay": return inlayColors()
  case "lamp": return lampColors()
  case "noir": return noirColors()
  case "ember": return emberColors()
  case "tide": return tideColors()
  case "bloom": return bloomColors()
  case "paper": return paperColors()
  case "chalk": return chalkColors()
  case "foam": return foamColors()
  case "petal": return petalColors()
  case "ink": return inkColors()
  default: return boomColors()
  }
}

public func boomColors() -> HelmColors {
  HelmColors(
    canvas: 0x0E1316, panel: 0x171D22, track: 0x232B32, line: 0x3A4550, edge: 0x5C6772,
    fg: 0xF4F0EA, body: 0xDCD6CE, muted: 0x9AA3AB, dim: 0x84909A, accent: 0xF07848,
    mark: 0xF3B199, accentLine: 0xC24A28, accentSoft: 0x2A1612, danger: 0xE070A0,
    ok: 0x3DB8A0, you: 0x3A1E16, kit: 0x232B32, scheme: "dark"
  )
}

private func inlayColors() -> HelmColors {
  HelmColors(
    canvas: 0x0C110F, panel: 0x151C19, track: 0x1E2823, line: 0x33423B, edge: 0x5A6E64,
    fg: 0xF2EBE0, body: 0xD9D0C4, muted: 0xA3ADA6, dim: 0x8A948C, accent: 0xE6D3B0,
    mark: 0xF7EBD4, accentLine: 0xA89068, accentSoft: 0x243028, danger: 0xD4787A,
    ok: 0x6BAF9A, you: 0x2A2820, kit: 0x1E2823, scheme: "dark"
  )
}

private func lampColors() -> HelmColors {
  HelmColors(
    canvas: 0x0C0C16, panel: 0x151522, track: 0x1E1E2E, line: 0x32324A, edge: 0x5A5A78,
    fg: 0xEEF0E6, body: 0xD5D8C8, muted: 0x9AA090, dim: 0x8A9088, accent: 0xC5D24A,
    mark: 0xE4EEC8, accentLine: 0x8A9430, accentSoft: 0x222418, danger: 0xE07090,
    ok: 0x5EC8B0, you: 0x2A2A18, kit: 0x1E1E2E, scheme: "dark"
  )
}

private func noirColors() -> HelmColors {
  HelmColors(
    canvas: 0x0A0C10, panel: 0x12151A, track: 0x1A1F28, line: 0x2E3644, edge: 0x5A6578,
    fg: 0xE8EEF4, body: 0xC5CED8, muted: 0x8A96A8, dim: 0x6E7A8C, accent: 0x8EB4D4,
    mark: 0xD4E4F4, accentLine: 0x4A78A0, accentSoft: 0x121820, danger: 0xD07090,
    ok: 0x5CB8A8, you: 0x1A2430, kit: 0x1A1F28, scheme: "dark"
  )
}

private func emberColors() -> HelmColors {
  HelmColors(
    canvas: 0x120C0A, panel: 0x1A1210, track: 0x261C16, line: 0x4A3430, edge: 0x7A5850,
    fg: 0xF4ECE4, body: 0xDCC8BC, muted: 0xB09080, dim: 0x8A7064, accent: 0xE07040,
    mark: 0xF4C4A0, accentLine: 0xA04828, accentSoft: 0x241410, danger: 0xE07090,
    ok: 0x6BB090, you: 0x2A1410, kit: 0x261C16, scheme: "dark"
  )
}

private func tideColors() -> HelmColors {
  HelmColors(
    canvas: 0x0A1214, panel: 0x101A1C, track: 0x182428, line: 0x2A3C44, edge: 0x4A6870,
    fg: 0xE4F0EE, body: 0xC4D8D4, muted: 0x88A8A8, dim: 0x6E8888, accent: 0x3CB8B0,
    mark: 0xB8ECE4, accentLine: 0x2A7878, accentSoft: 0x102020, danger: 0xD07890,
    ok: 0x4CBC9C, you: 0x142428, kit: 0x182428, scheme: "dark"
  )
}

private func bloomColors() -> HelmColors {
  HelmColors(
    canvas: 0x100C14, panel: 0x18141E, track: 0x221C2A, line: 0x3A3048, edge: 0x6A5878,
    fg: 0xF0E8F4, body: 0xD8D0DC, muted: 0xA890B0, dim: 0x8A7898, accent: 0xD070C0,
    mark: 0xF0C8E8, accentLine: 0x884878, accentSoft: 0x20141E, danger: 0xE07090,
    ok: 0x68B8A0, you: 0x241428, kit: 0x221C2A, scheme: "dark"
  )
}

private func paperColors() -> HelmColors {
  HelmColors(
    canvas: 0xF6F1E8, panel: 0xEFE8DC, track: 0xE4DCCF, line: 0x8E8270, edge: 0x5A5248,
    fg: 0x1C1814, body: 0x2E2822, muted: 0x524A42, dim: 0x5C544C, accent: 0xC24A28,
    mark: 0x8A2808, accentLine: 0xA83818, accentSoft: 0xF3D8CC, danger: 0xB42858,
    ok: 0x1A7A64, you: 0xE4C4B0, kit: 0xE4DCCF, scheme: "light"
  )
}

private func chalkColors() -> HelmColors {
  HelmColors(
    canvas: 0xF2F5F8, panel: 0xE6ECF2, track: 0xD8E0E8, line: 0x7A8A98, edge: 0x4A5A68,
    fg: 0x12161C, body: 0x1E2630, muted: 0x3A4856, dim: 0x465462, accent: 0x1E5A8C,
    mark: 0x0E3A60, accentLine: 0x164A74, accentSoft: 0xD0E0F0, danger: 0xB42858,
    ok: 0x1A7060, you: 0xC8D6E4, kit: 0xD8E0E8, scheme: "light"
  )
}

private func foamColors() -> HelmColors {
  HelmColors(
    canvas: 0xEEF6F5, panel: 0xE0EEEC, track: 0xD0E4E0, line: 0x5E8884, edge: 0x3A5C58,
    fg: 0x102018, body: 0x1A2C2A, muted: 0x345250, dim: 0x425E5C, accent: 0x0C6E68,
    mark: 0x064840, accentLine: 0x0A5C58, accentSoft: 0xC4E8E4, danger: 0xB42858,
    ok: 0x1A7A64, you: 0xB8D8D4, kit: 0xD0E4E0, scheme: "light"
  )
}

private func petalColors() -> HelmColors {
  HelmColors(
    canvas: 0xF7F1F6, panel: 0xEFE4EE, track: 0xE6D8E6, line: 0x8E748E, edge: 0x5A485A,
    fg: 0x1A121C, body: 0x2A2030, muted: 0x4E3E56, dim: 0x5A4A62, accent: 0xA02080,
    mark: 0x6E0858, accentLine: 0x881068, accentSoft: 0xF4D0E8, danger: 0xB42858,
    ok: 0x1A7A64, you: 0xE4C0DC, kit: 0xE6D8E6, scheme: "light"
  )
}

private func inkColors() -> HelmColors {
  HelmColors(
    canvas: 0x050506, panel: 0x141416, track: 0x262628, line: 0x6A6A70, edge: 0x9A9AA0,
    fg: 0xFAFAFA, body: 0xE4E4E6, muted: 0xB0B0B6, dim: 0xC4C4CA, accent: 0xF0B020,
    mark: 0xFFE08A, accentLine: 0xC88810, accentSoft: 0x2A220C, danger: 0xF07090,
    ok: 0x3CC8A8, you: 0x3A2410, kit: 0x262628, scheme: "dark"
  )
}
