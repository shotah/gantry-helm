import XCTest
@testable import Mailbox

final class LookAvatarPaletteTests: XCTestCase {
  func testThemeFallsBackToBoom() {
    XCTAssertEqual(defaultTheme, parseTheme(nil))
    XCTAssertEqual("boom", parseTheme("nope"))
    XCTAssertEqual("inlay", parseTheme("inlay"))
    XCTAssertEqual("lamp", parseTheme("lamp"))
    XCTAssertEqual("noir", parseTheme("noir"))
    XCTAssertEqual(
      [
        "boom", "inlay", "lamp", "noir", "ember", "tide", "bloom",
        "paper", "chalk", "foam", "petal", "ink",
      ],
      themeIds
    )
    XCTAssertEqual("paper", parseTheme("paper"))
    XCTAssertEqual("ink", knownTheme("ink"))
    XCTAssertEqual("noir", knownTheme("noir"))
    XCTAssertNil(knownTheme("nope"))
  }

  func testFollowPaintsTheRoomThemeUntilItIsCleared() {
    XCTAssertEqual("noir", paintedTheme(follow: true, roomTheme: "noir", mine: "boom"))
    XCTAssertEqual("boom", paintedTheme(follow: true, roomTheme: "", mine: "boom"))
    XCTAssertEqual("boom", paintedTheme(follow: true, roomTheme: "nope", mine: "boom"))
    XCTAssertEqual("lamp", paintedTheme(follow: false, roomTheme: "noir", mine: "lamp"))
  }

  func testFontFallsBackToSmall() {
    XCTAssertEqual(defaultFont, parseFont(nil))
    XCTAssertEqual("sm", parseFont("nope"))
    XCTAssertEqual("lg", parseFont("lg"))
    XCTAssertEqual(["sm", "md", "lg", "xl"], fontIds)
    XCTAssertEqual(14, chatSp("sm"), accuracy: 0.01)
    XCTAssertEqual(16, chatSp("md"), accuracy: 0.01)
    XCTAssertEqual(20, chatSp("lg"), accuracy: 0.01)
    XCTAssertEqual(24, chatSp("xl"), accuracy: 0.01)
    XCTAssertEqual(14, chatSp("nope"), accuracy: 0.01)
  }

  func testLabelsMatchPendant() {
    XCTAssertEqual("Boom", themeLabel("boom"))
    XCTAssertEqual("Boom", themeLabel("nope"))
    XCTAssertEqual("Inlay", themeLabel("inlay"))
    XCTAssertEqual("Noir", themeLabel("noir"))
    XCTAssertEqual("Paper", themeLabel("paper"))
    XCTAssertEqual("Chalk", themeLabel("chalk"))
    XCTAssertEqual("Foam", themeLabel("foam"))
    XCTAssertEqual("Petal", themeLabel("petal"))
    XCTAssertEqual("Ink", themeLabel("ink"))
    XCTAssertEqual("Small", fontLabel("sm"))
    XCTAssertEqual("Medium", fontLabel("md"))
    XCTAssertEqual("Large", fontLabel("lg"))
    XCTAssertEqual("Extra large", fontLabel("xl"))
  }

  func testHeaderFaceMatchesCabAndPendant() {
    XCTAssertEqual(82, headerFaceSize, accuracy: 0.01)
    XCTAssertEqual(80, headerFaceSlotWidth, accuracy: 0.01)
    XCTAssertEqual(40, headerFaceSlotHeight, accuracy: 0.01)
    XCTAssertEqual(-2, headerFaceNudgeX, accuracy: 0.01)
    XCTAssertEqual(-4, headerFaceNudgeY, accuracy: 0.01)
    XCTAssertEqual(2, headerFaceStroke, accuracy: 0.01)
  }

  func testDisplaySlugTitleCases() {
    XCTAssertEqual("Kit", displaySlug(""))
    XCTAssertEqual("Kit", displaySlug("  "))
    XCTAssertEqual("Kit", displaySlug("kit"))
    XCTAssertEqual("Ada", displaySlug("ada"))
  }

  func testBlobEtagAndRevRoundTripThePendantHeaders() {
    XCTAssertEqual("\"7\"", blobEtag(7))
    XCTAssertEqual(7, blobRev("7", etag: nil))
    XCTAssertEqual(7, blobRev(nil, etag: "\"7\""))
    XCTAssertEqual(7, blobRev(nil, etag: "W/\"7\""))
    XCTAssertEqual(12, blobRev("12", etag: "\"7\""))
    XCTAssertEqual(0, blobRev(nil, etag: nil))
    XCTAssertEqual(0, blobRev("0", etag: "\"-3\""))
    XCTAssertEqual(0, blobRev("nope", etag: "\"abc\""))
  }

  func testFaceRevOnlyFromFaceKind() {
    XCTAssertEqual(9, faceRev("face", "9"))
    XCTAssertNil(faceRev("reply", "9"))
    XCTAssertNil(faceRev("face", "nope"))
    XCTAssertNil(faceRev("face", "0"))
    XCTAssertNil(faceRev("face", "-1"))
    XCTAssertNil(faceRev("face", nil))
  }

  func testAvatarUrlPinsARev() {
    XCTAssertEqual(
      "https://example.workers.dev/api/avatar?slug=kit",
      avatarUrl("https://example.workers.dev/", slug: "kit")
    )
    XCTAssertEqual(
      "https://example.workers.dev/api/avatar?slug=kit&v=3",
      avatarUrl("https://example.workers.dev/", slug: "kit", rev: 3)
    )
  }

  func testBackdropAndThemeUrlsMatchTheWorker() {
    XCTAssertEqual(
      "https://example.workers.dev/api/backdrop?slug=kit",
      backdropUrl("https://example.workers.dev/", slug: "kit")
    )
    XCTAssertEqual(
      "https://example.workers.dev/api/backdrop?slug=kit&v=9",
      backdropUrl("https://example.workers.dev/", slug: "kit", rev: 9)
    )
    XCTAssertEqual(
      "https://example.workers.dev/api/theme?slug=kit",
      themeUrl("https://example.workers.dev/", slug: "kit")
    )
  }

  func testBackdropRevAllowsZeroAndDropsJunk() {
    XCTAssertEqual(0, backdropRev("backdrop", 0))
    XCTAssertEqual(9, backdropRev("backdrop", 9))
    XCTAssertNil(backdropRev("backdrop", -1))
    XCTAssertNil(backdropRev("backdrop", 1.5))
    XCTAssertNil(backdropRev("face", 9))
    XCTAssertNil(backdropRev("backdrop", nil as Any?))
  }

  func testRoomThemeNoticeClearsOnNullAndIgnoresJunk() {
    XCTAssertEqual("lamp", roomThemeNotice("theme", themePresent: true, themeNull: false, themeRaw: "lamp"))
    XCTAssertEqual("", roomThemeNotice("theme", themePresent: true, themeNull: true, themeRaw: "lamp"))
    XCTAssertEqual("", roomThemeNotice("theme", themePresent: false, themeNull: false, themeRaw: nil))
    XCTAssertNil(roomThemeNotice("theme", themePresent: true, themeNull: false, themeRaw: "nope"))
    XCTAssertNil(roomThemeNotice("face", themePresent: true, themeNull: false, themeRaw: "lamp"))
  }

  func testThemesKeepTheirAccents() {
    XCTAssertEqual(0xF07848, helmColors("boom").accent)
    XCTAssertEqual(0xE6D3B0, helmColors("inlay").accent)
    XCTAssertEqual(0xC5D24A, helmColors("lamp").accent)
    XCTAssertEqual(helmColors("boom").accent, helmColors("nope").accent)
    XCTAssertEqual(0x0E1316, helmColors("boom").canvas)
    XCTAssertEqual(0x8EB4D4, helmColors("noir").accent)
    XCTAssertEqual(0xE07040, helmColors("ember").accent)
    XCTAssertEqual(0x3CB8B0, helmColors("tide").accent)
    XCTAssertEqual(0xD070C0, helmColors("bloom").accent)
    XCTAssertEqual("light", helmColors("paper").scheme)
    XCTAssertEqual(0xC24A28, helmColors("paper").accent)
    XCTAssertEqual(0x1E5A8C, helmColors("chalk").accent)
    XCTAssertEqual(0x0C6E68, helmColors("foam").accent)
    XCTAssertEqual(0xA02080, helmColors("petal").accent)
    XCTAssertEqual(0xF0B020, helmColors("ink").accent)
    XCTAssertEqual("dark", helmColors("ink").scheme)
    XCTAssertEqual(0xF6F1E8, helmColors("paper").canvas)
  }

  func testDaylightCousinsStayLightAndInkStaysDark() {
    let light: Set<String> = ["paper", "chalk", "foam", "petal"]
    XCTAssertEqual(
      themeIds,
      [
        "boom", "inlay", "lamp", "noir", "ember", "tide", "bloom",
        "paper", "chalk", "foam", "petal", "ink",
      ]
    )
    for id in themeIds {
      XCTAssertEqual(light.contains(id) ? "light" : "dark", helmColors(id).scheme)
    }
    XCTAssertEqual(0xE4C4B0, helmColors("paper").you)
    XCTAssertEqual(0xF2F5F8, helmColors("chalk").canvas)
    XCTAssertEqual(0xEEF6F5, helmColors("foam").canvas)
    XCTAssertEqual(0xF7F1F6, helmColors("petal").canvas)
    XCTAssertEqual(0x050506, helmColors("ink").canvas)
    XCTAssertEqual(0x3A2410, helmColors("ink").you)
    XCTAssertEqual(0xC4C4CA, helmColors("ink").dim)
    XCTAssertEqual(0x3DB8A0, boomColors().ok)
  }
}
