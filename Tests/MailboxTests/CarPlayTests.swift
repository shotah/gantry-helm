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
    XCTAssertFalse(encodeFrame(inbound("hi", id: "c2", context: PhoneContext(surface: "ios"))).isEmpty)
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
    XCTAssertNil(
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
    XCTAssertEqual("Kit", kitReplyPreview)
  }
}
