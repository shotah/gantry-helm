import XCTest

@testable import Mailbox

final class CarPlayTests: XCTestCase {
  func testSurfaceHintTagsCarplayWhenTheHeadUnitIsOn() {
    XCTAssertEqual("carplay", surfaceHint(carAttached: true))
    XCTAssertEqual("ios", surfaceHint(carAttached: false))
    XCTAssertEqual("carplay", surfaceOnWire("carplay"))
    XCTAssertEqual("ios", surfaceOnWire("ios"))
    XCTAssertNil(surfaceOnWire("dashboard"))
  }

  func testInboundFromTheCarKeepsSurfaceOnTheWire() {
    let frame = inbound(
      "leave by 8",
      id: "c1",
      context: PhoneContext(surface: surfaceHint(carAttached: true))
    )
    let raw = encodeFrame(frame)
    XCTAssertEqual("carplay", frame.context?.surface)
    XCTAssertTrue(raw.contains("carplay"))
    XCTAssertFalse(
      encodeFrame(inbound("hi", id: "c2", context: PhoneContext(surface: "ios"))).isEmpty)
  }

  func testCarAudioPortMeansAttachedLikeCabProjection() {
    XCTAssertFalse(carPlayRouteAttached(portTypes: []))
    XCTAssertFalse(carPlayRouteAttached(portTypes: ["Speaker"]))
    XCTAssertTrue(carPlayRouteAttached(portTypes: ["Speaker", carAudioPort]))
    XCTAssertEqual("CarAudio", carAudioPort)
  }

  func testSpokenReplyNeedsText() {
    XCTAssertNil(carPlayReplyText(nil))
    XCTAssertNil(carPlayReplyText("  "))
    XCTAssertEqual("on the dock", carPlayReplyText("  on the dock  "))
  }

  func testKitNoticePostsOnlyWhenTheCarGateSaysSo() {
    XCTAssertEqual(
      "leave by 8",
      kitNoticeBody(
        painted: true, kind: "reply", replay: false, resumed: false, carAttached: false,
        threadVisible: false, text: "leave by 8", hasPhoto: false
      )
    )
    XCTAssertEqual(
      "Photo",
      kitNoticeBody(
        painted: true, kind: "push", replay: false, resumed: true, carAttached: true,
        threadVisible: false, text: "  ", hasPhoto: true
      )
    )
    XCTAssertEqual(
      "hi",
      kitNoticeBody(
        painted: true, kind: "reply", replay: false, resumed: true, carAttached: false,
        threadVisible: false, text: "hi", hasPhoto: false
      )
    )
    XCTAssertNil(
      kitNoticeBody(
        painted: true, kind: "inbound", replay: false, resumed: false, carAttached: true,
        threadVisible: false, text: "sibling", hasPhoto: false
      )
    )
    XCTAssertNil(
      kitNoticeBody(
        painted: true, kind: "reply", replay: true, resumed: false, carAttached: true,
        threadVisible: false, text: "hydrate", hasPhoto: false
      )
    )
    XCTAssertNil(
      kitNoticeBody(
        painted: false, kind: "reply", replay: false, resumed: false, carAttached: true,
        threadVisible: false, text: "control", hasPhoto: false
      )
    )
  }

  func testSweepWaitsForTheGapAndAWatchingMouth() {
    XCTAssertFalse(shouldSweepNow(watching: false, openedAt: 0, now: sweepMinGapMs + 1))
    XCTAssertFalse(shouldSweepNow(watching: true, openedAt: 100, now: 100 + sweepMinGapMs - 1))
    XCTAssertTrue(shouldSweepNow(watching: true, openedAt: 100, now: 100 + sweepMinGapMs))
  }

  func testNoticeConstantsMatchTheCarPlayCard() {
    XCTAssertEqual("kit.reply", kitReplyCategory)
    XCTAssertEqual("reply", kitReplyAction)
    XCTAssertEqual("kit", kitReplyThread)
    XCTAssertEqual("%u new messages", kitReplyPreview)
  }

  func testProfileEntitlementsComeOutOfTheCmsWrappedPlist() {
    let plist = """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict>
        <key>Name</key><string>iOS Team Provisioning Profile</string>
        <key>Entitlements</key><dict>
          <key>\(communicationEntitlement)</key><true/>
          <key>\(timeSensitiveEntitlement)</key><false/>
        </dict>
      </dict></plist>
      """
    var profile = Data([0x30, 0x82, 0x1a, 0xff, 0x06, 0x09])
    profile.append(Data(plist.utf8))
    profile.append(Data([0x00, 0x31, 0x82, 0x02]))
    let got = profileEntitlements(profile)
    XCTAssertTrue(entitled(got, communicationEntitlement))
    XCTAssertFalse(entitled(got, timeSensitiveEntitlement))
    XCTAssertFalse(entitled(got, "com.apple.developer.nope"))
  }

  func testNoProfileMeansNoEntitlements() {
    XCTAssertTrue(profileEntitlements(nil).isEmpty)
    XCTAssertTrue(profileEntitlements(Data([0x30, 0x82])).isEmpty)
    XCTAssertTrue(profileEntitlements(Data("<?xml version=\"1.0\"?><plist>".utf8)).isEmpty)
    XCTAssertFalse(entitled([:], communicationEntitlement))
  }
}
