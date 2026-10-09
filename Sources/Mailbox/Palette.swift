/// Boom hexes must not drift from pendant `lib/theme/catalog.ts` / gantree.
/// Mood blocks are the catalog dozen. Values are 0xRRGGBB (opaque).
/// SwiftUI maps them in the app target. `scheme` drives preferredColorScheme.
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
  case "paper": return paperColors()
  case "ink": return inkColors()
  case "marquee": return marqueeColors()
  case "lemonade": return lemonadeColors()
  case "neon": return neonColors()
  case "fizz": return fizzColors()
  case "rain": return rainColors()
  case "mist": return mistColors()
  case "fuse": return fuseColors()
  case "grit": return gritColors()
  case "siren": return sirenColors()
  case "flare": return flareColors()
  case "static": return staticColors()
  case "flicker": return flickerColors()
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

private func paperColors() -> HelmColors {
  HelmColors(
    canvas: 0xF6F1E8, panel: 0xEFE8DC, track: 0xE4DCCF, line: 0x8E8270, edge: 0x5A5248,
    fg: 0x1C1814, body: 0x2E2822, muted: 0x524A42, dim: 0x5C544C, accent: 0xC24A28,
    mark: 0x8A2808, accentLine: 0xA83818, accentSoft: 0xF3D8CC, danger: 0xB42858,
    ok: 0x1A7A64, you: 0xE4C4B0, kit: 0xE4DCCF, scheme: "light"
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

private func marqueeColors() -> HelmColors {
  HelmColors(
    canvas: 0x141A3C, panel: 0x1C2450, track: 0x283064, line: 0x46508C, edge: 0x7A84B8,
    fg: 0xFFF8E6, body: 0xE6E0D0, muted: 0xB0B4D8, dim: 0x9AA0C8, accent: 0xFFCC33,
    mark: 0xFFE599, accentLine: 0xC99A10, accentSoft: 0x332A12, danger: 0xFF6B9D,
    ok: 0x3AD0A0, you: 0x2A2470, kit: 0x283064, scheme: "dark"
  )
}

private func lemonadeColors() -> HelmColors {
  HelmColors(
    canvas: 0xFFF6CC, panel: 0xFFF0B0, track: 0xF7E690, line: 0xA89440, edge: 0x6E6020,
    fg: 0x1A1606, body: 0x2E2810, muted: 0x5A5020, dim: 0x665C28, accent: 0x1F52E0,
    mark: 0x10308C, accentLine: 0x1842B8, accentSoft: 0xDDE6FF, danger: 0xC0184C,
    ok: 0x167A4A, you: 0xFFD84D, kit: 0xF7E690, scheme: "light"
  )
}

private func neonColors() -> HelmColors {
  HelmColors(
    canvas: 0x120A1E, panel: 0x1B1030, track: 0x281848, line: 0x4A2E7A, edge: 0x7E58B8,
    fg: 0xFDF2FF, body: 0xE6D8F2, muted: 0xB89AD8, dim: 0xA088C4, accent: 0xFF2D95,
    mark: 0xFFA6D2, accentLine: 0xC0106A, accentSoft: 0x3A1030, danger: 0xFF5A5A,
    ok: 0x2EF2B0, you: 0x3A1458, kit: 0x281848, scheme: "dark"
  )
}

private func fizzColors() -> HelmColors {
  HelmColors(
    canvas: 0xE6FBFF, panel: 0xD2F4FB, track: 0xBCEAF4, line: 0x4E8A98, edge: 0x2E5C68,
    fg: 0x081A20, body: 0x142A32, muted: 0x2E5260, dim: 0x3A5E6C, accent: 0xE0107A,
    mark: 0x8E0848, accentLine: 0xC00C66, accentSoft: 0xFFD6EA, danger: 0xC4123A,
    ok: 0x0E7A5A, you: 0xB0EEFC, kit: 0xBCEAF4, scheme: "light"
  )
}

private func rainColors() -> HelmColors {
  HelmColors(
    canvas: 0x0F131F, panel: 0x161C2C, track: 0x20283C, line: 0x364260, edge: 0x5C6A90,
    fg: 0xE8ECF8, body: 0xC8D0E4, muted: 0x8E9AC0, dim: 0x8894BA, accent: 0x8C9FE6,
    mark: 0xC8D4FF, accentLine: 0x4E60A8, accentSoft: 0x1A2040, danger: 0xD06A90,
    ok: 0x5CB09A, you: 0x1E2644, kit: 0x20283C, scheme: "dark"
  )
}

private func mistColors() -> HelmColors {
  HelmColors(
    canvas: 0xECEEF6, panel: 0xE0E3EE, track: 0xD0D4E4, line: 0x7E86A4, edge: 0x505870,
    fg: 0x14161E, body: 0x22262E, muted: 0x464C62, dim: 0x4C526A, accent: 0x4A56A8,
    mark: 0x2A3270, accentLine: 0x3C4690, accentSoft: 0xD8DCF6, danger: 0xB02858,
    ok: 0x1E7462, you: 0xC8CCEC, kit: 0xD0D4E4, scheme: "light"
  )
}

private func fuseColors() -> HelmColors {
  HelmColors(
    canvas: 0x17150F, panel: 0x201D14, track: 0x2C281C, line: 0x4E4830, edge: 0x7C7450,
    fg: 0xFBF4E6, body: 0xE2D8C4, muted: 0xAEA48A, dim: 0xA0967E, accent: 0xFF7A00,
    mark: 0xFFBF80, accentLine: 0xC45A00, accentSoft: 0x33200A, danger: 0xFF5A6E,
    ok: 0x86C46A, you: 0x332A16, kit: 0x2C281C, scheme: "dark"
  )
}

private func gritColors() -> HelmColors {
  HelmColors(
    canvas: 0xF3EFE4, panel: 0xE9E3D2, track: 0xDCD4BC, line: 0x8A8060, edge: 0x5A5238,
    fg: 0x1A1810, body: 0x2C2818, muted: 0x504A30, dim: 0x5A543A, accent: 0xD2500A,
    mark: 0x8A3004, accentLine: 0xB44208, accentSoft: 0xFFDCC4, danger: 0xB4203A,
    ok: 0x4A7A1E, you: 0xEAD29A, kit: 0xDCD4BC, scheme: "light"
  )
}

private func sirenColors() -> HelmColors {
  HelmColors(
    canvas: 0x160608, panel: 0x200A0E, track: 0x2E1016, line: 0x58202A, edge: 0x8E3A48,
    fg: 0xFFF2F2, body: 0xECD4D6, muted: 0xC09AA0, dim: 0xAE8A90, accent: 0xFF2E3F,
    mark: 0xFFA0A8, accentLine: 0xC0101E, accentSoft: 0x3E0C12, danger: 0xFF6AB8,
    ok: 0x46D08A, you: 0x3A0E18, kit: 0x2E1016, scheme: "dark"
  )
}

private func flareColors() -> HelmColors {
  HelmColors(
    canvas: 0xFFF0EE, panel: 0xFDE0DC, track: 0xF6CCC6, line: 0xA06860, edge: 0x6A4038,
    fg: 0x1E0A0A, body: 0x301616, muted: 0x5A3030, dim: 0x663A3A, accent: 0xD4102C,
    mark: 0x880818, accentLine: 0xB00C22, accentSoft: 0xFFD4D4, danger: 0xB0147A,
    ok: 0x1A7A4E, you: 0xFFC2BC, kit: 0xF6CCC6, scheme: "light"
  )
}

private func staticColors() -> HelmColors {
  HelmColors(
    canvas: 0x0D1410, panel: 0x141C17, track: 0x1E2A22, line: 0x37493D, edge: 0x5E7866,
    fg: 0xF0F8F2, body: 0xD2DCD6, muted: 0x9AB0A2, dim: 0x8AA092, accent: 0xB388FF,
    mark: 0xDCC8FF, accentLine: 0x7A4EE0, accentSoft: 0x221A38, danger: 0xFF6A8A,
    ok: 0x52D490, you: 0x26203C, kit: 0x1E2A22, scheme: "dark"
  )
}

private func flickerColors() -> HelmColors {
  HelmColors(
    canvas: 0xEEF7F0, panel: 0xDFF0E4, track: 0xCCE4D4, line: 0x6A8E78, edge: 0x40604C,
    fg: 0x0E1A12, body: 0x1A2A20, muted: 0x365244, dim: 0x425E50, accent: 0x6A2FD0,
    mark: 0x3E1484, accentLine: 0x5824B0, accentSoft: 0xE8DCFF, danger: 0xB4204E,
    ok: 0x1A7A4A, you: 0xD8D0F8, kit: 0xCCE4D4, scheme: "light"
  )
}
