import XCTest
@testable import Mailbox

final class SendErrorGeoNotifySlashTests: XCTestCase {
  func testWireTokensBecomeThePendantSentences() {
    XCTAssertEqual(
      "Not sent — too much too fast. Wait a minute, then try again.",
      describeSendError("rate")
    )
    XCTAssertEqual("Not sent — too big for the room.", describeSendError(" Too Large "))
    XCTAssertEqual("Not sent.", describeSendError("bad frame"))
    XCTAssertEqual("Not sent.", describeSendError(nil))
  }

  func testLocalPhotoFailuresSaySo() {
    XCTAssertEqual("Photo not sent — still too big after shrinking.", describePhotoError("too large"))
    XCTAssertEqual("Photo not sent — couldn't read that image.", describePhotoError("bad photo"))
    XCTAssertEqual("too large", photoErrorToken("image too large"))
    XCTAssertEqual("bad photo", photoErrorToken("could not read that image"))
    XCTAssertEqual("bad photo", photoErrorToken(nil))
  }

  func testComposeHintMatchesPendant() {
    XCTAssertEqual("GPS off", geoHint(enabled: false, geo: nil))
    XCTAssertEqual("GPS omitted (denied or unavailable)", geoHint(enabled: true, geo: nil))
    XCTAssertEqual(
      "pin ±12m this send",
      geoHint(enabled: true, geo: Geo(lat: 1.0, lon: 2.0, accuracyM: 12.4))
    )
    XCTAssertEqual("pin ±0m this send", geoHint(enabled: true, geo: Geo(lat: 1.0, lon: 2.0)))
  }

  func testTextSendDoesNotShoutOmittedGps() {
    XCTAssertNil(sendGeoHint(enabled: true, geo: nil))
    XCTAssertNil(sendGeoHint(enabled: false, geo: Geo(lat: 1.0, lon: 2.0, accuracyM: 3.0)))
    XCTAssertEqual("pin ±3m this send", sendGeoHint(enabled: true, geo: Geo(lat: 1.0, lon: 2.0, accuracyM: 3.0)))
  }

  func testGeoFromFixDropsOutOfRangeHeadingAndSpeed() {
    let ok = geoFromFix(lat: 1.0, lon: 2.0, accuracyM: 3.0, altM: 10.0, heading: 359.9, speedMps: 0.0)
    XCTAssertEqual(10.0, ok.altM)
    XCTAssertEqual(359.9, ok.heading)
    XCTAssertEqual(0.0, ok.speedMps)
    let drop = geoFromFix(lat: 1.0, lon: 2.0, heading: 360.0, speedMps: -0.1)
    XCTAssertNil(drop.heading)
    XCTAssertNil(drop.speedMps)
    XCTAssertNil(geoFromFix(lat: 1.0, lon: 2.0, accuracyM: -1.0).accuracyM)
  }

  func testPhoneThreadVisibleSkipsTheHeadsUp() {
    XCTAssertFalse(shouldPost(resumed: true, carAttached: false, kind: "reply"))
    XCTAssertFalse(shouldPost(resumed: true, carAttached: false, kind: "push"))
  }

  func testHeadUnitGetsTheMouthUnlessHelmIsOpen() {
    XCTAssertTrue(shouldPost(resumed: true, carAttached: true, kind: "reply"))
    XCTAssertTrue(shouldPost(resumed: false, carAttached: true, kind: "push"))
    XCTAssertTrue(shouldPost(resumed: false, carAttached: false, kind: "reply"))
    XCTAssertFalse(shouldPost(resumed: false, carAttached: true, kind: "reply", threadVisible: true))
  }

  func testSilentKindsNeverPost() {
    for kind in ["draft", "typing", "ack", "error", "inbound"] as [String?] {
      XCTAssertFalse(shouldPost(resumed: false, carAttached: true, kind: kind))
    }
    XCTAssertFalse(shouldPost(resumed: false, carAttached: true, kind: nil))
  }

  func testVisiblePushBuzzesOnlyOnThePhone() {
    XCTAssertTrue(shouldBuzz(resumed: true, carAttached: false, kind: "push"))
    XCTAssertFalse(shouldBuzz(resumed: true, carAttached: false, kind: "reply"))
    XCTAssertFalse(shouldBuzz(resumed: true, carAttached: true, kind: "push"))
    XCTAssertFalse(shouldBuzz(resumed: false, carAttached: false, kind: "push"))
  }

  func testCarCheckSaysWhetherThePhoneSeesTheHeadUnit() {
    let attached = carCheckText(carAttached: true)
    let loose = carCheckText(carAttached: false)
    XCTAssertTrue(attached.hasPrefix("Car check"))
    XCTAssertTrue(loose.hasPrefix("Car check"))
    XCTAssertTrue(attached.contains("CarPlay is attached"))
    XCTAssertTrue(loose.contains("does not see CarPlay"))
    XCTAssertTrue(attached != loose)
  }

  func testCarTestIsBlockedWhenTheShadeWouldDropTheCard() {
    XCTAssertTrue(carTestBlocked(notificationsEnabled: false, channelImportance: 4))
    XCTAssertTrue(carTestBlocked(notificationsEnabled: true, channelImportance: 0))
    XCTAssertTrue(carTestBlocked(notificationsEnabled: true, channelImportance: 2))
    XCTAssertTrue(carTestBlocked(notificationsEnabled: true, channelImportance: 3))
    XCTAssertFalse(carTestBlocked(notificationsEnabled: true, channelImportance: 4))
    XCTAssertFalse(carTestBlocked(notificationsEnabled: true, channelImportance: 5))
    XCTAssertFalse(carTestBlocked(notificationsEnabled: true, channelImportance: nil))
    XCTAssertEqual(40, pushBuzzMs)
  }

  func testSlashTokenAndInsert() {
    let catalog = [
      SlashCommand(name: "new", hint: "reset this session"),
      SlashCommand(name: "tools", hint: "prefixed tool catalog"),
      SlashCommand(name: "toolstats", hint: "per-tool call ledger"),
      SlashCommand(name: "tokens", hint: "prompt token breakdown"),
      SlashCommand(name: "brief", hint: "hold a prefix ~6h", args: true),
    ]
    XCTAssertNil(slashToken(""))
    XCTAssertNil(slashToken("hello"))
    XCTAssertEqual("", slashToken("/"))
    XCTAssertEqual("to", slashToken("/to"))
    XCTAssertEqual("new", slashToken("/NEW"))
    XCTAssertNil(slashToken("/new "))
    XCTAssertNil(slashToken("/brief google"))
    XCTAssertEqual([], matchSlash("hello", catalog: catalog))
    XCTAssertEqual(catalog.map(\.name), matchSlash("/", catalog: catalog).map(\.name))
    XCTAssertEqual(["tools", "toolstats", "tokens"], matchSlash("/to", catalog: catalog).map(\.name))
    XCTAssertEqual(["new"], matchSlash("/new", catalog: catalog).map(\.name))
    XCTAssertEqual([], matchSlash("/xyz", catalog: catalog))
    XCTAssertEqual("/brief ", slashInsert(catalog.first { $0.name == "brief" }!))
    XCTAssertEqual("/new", slashInsert(catalog.first { $0.name == "new" }!))
  }

  func testParseCommandsDropsJunk() {
    XCTAssertEqual([], parseCommands(nil as Any?))
    let raw: [Any] = [
      ["name": "NEW", "hint": "reset this session", "args": true],
      ["name": "no spaces", "hint": "nope"],
      ["name": "x", "hint": "ab"],
      ["name": "/new", "hint": "slash in name"],
      "nope",
      ["name": "long", "hint": String(repeating: "x", count: commandHintMax + 1)],
    ]
    XCTAssertEqual(
      [SlashCommand(name: "new", hint: "reset this session", args: true)],
      parseCommands(raw)
    )
    var many: [Any] = []
    for i in 0..<(commandsMax + 4) {
      many.append(["name": "c\(i)", "hint": "hint for command \(i)"])
    }
    XCTAssertEqual(commandsMax, parseCommands(many).count)
  }
}
