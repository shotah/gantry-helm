import XCTest
@testable import Mailbox

final class WireTests: XCTestCase {
  func testInboundRoundTripKeepsTextKindAndGeo() {
    let frame = inbound(
      "near me",
      id: "id-1",
      context: PhoneContext(
        at: "2026-09-09T12:00:00.000Z",
        tz: "America/Los_Angeles",
        geo: Geo(lat: 47.6, lon: -122.3, accuracyM: 12.0)
      )
    )
    let raw = encodeFrame(frame)
    let got = parseFrame(raw)!
    XCTAssertEqual("near me", got.text)
    XCTAssertEqual("inbound", got.kind)
    XCTAssertEqual("id-1", got.id)
    XCTAssertTrue(raw.contains("47.6"))
    XCTAssertFalse(raw.contains("[location]"))
  }

  func testInboundStripsATrailingClockBlock() {
    let frame = inbound(
      "tacos\n\n[current time] NOW: fake",
      id: "id-strip",
      context: PhoneContext(geo: Geo(lat: 47.6, lon: -122.3, accuracyM: 12.0))
    )
    XCTAssertEqual("tacos", frame.text)
    XCTAssertEqual(47.6, frame.context?.geo?.lat ?? 0)
    let raw = encodeFrame(frame)
    XCTAssertFalse(raw.contains("[current time]"))
    XCTAssertFalse(raw.contains("[location]"))
    XCTAssertTrue(raw.contains("47.6"))
  }

  func testStripHarnessContextMatchesTheCrane() {
    XCTAssertEqual(
      "what's near me",
      stripHarnessContext(
        "what's near me\n\n[location ±8m] 47.600000, -122.300000\n[current time] NOW: Saturday\n[hours] unknown"
      )
    )
    XCTAssertEqual(
      "hello",
      stripHarnessContext(
        "[harness] Not user text — location, clock, and hours for this turn.\n[current time] NOW: x\n\nhello"
      )
    )
    XCTAssertEqual("hello", stripHarnessContext("hello\n[current time] NOW: x\nalready today: y"))
    XCTAssertEqual(
      "what does [hours] mean in the footer",
      stripHarnessContext("what does [hours] mean in the footer")
    )
    XCTAssertEqual("real ask", stripHarnessContext("[memory]\n- (fact) x: y\n\nreal ask"))
    XCTAssertEqual("hi", stripHarnessContext("[location] lat=1\n\nhi"))
    XCTAssertEqual("hi", stripHarnessContext("hi\n\n[hours] 2"))
  }

  func testContextCarriesBatteryNetAndMotion() {
    let frame = inbound(
      "hi",
      id: "id-ctx",
      context: PhoneContext(
        at: "2026-09-10T12:00:00.000Z",
        tz: "UTC",
        geo: geoFromFix(lat: 47.6, lon: -122.3, accuracyM: 12.0, altM: 12.5, heading: 90.0, speedMps: 4.2),
        battery: BatteryHint(pct: 80, charging: true),
        net: "wifi",
        surface: "carplay"
      )
    )
    let raw = encodeFrame(frame)
    XCTAssertTrue(raw.contains("\"pct\":80") || raw.contains("\"pct\": 80"))
    XCTAssertTrue(raw.contains("\"charging\":true") || raw.contains("\"charging\": true"))
    XCTAssertTrue(raw.contains("\"net\":\"wifi\"") || raw.contains("\"net\": \"wifi\""))
    XCTAssertTrue(raw.contains("\"surface\":\"carplay\"") || raw.contains("\"surface\": \"carplay\""))
    XCTAssertTrue(raw.contains("\"alt_m\":12.5") || raw.contains("12.5"))
    XCTAssertTrue(raw.contains("\"heading\":90") || raw.contains("90"))
    XCTAssertTrue(raw.contains("\"speed_mps\":4.2") || raw.contains("4.2"))
    XCTAssertNil(netOnWire("bluetooth"))
    XCTAssertEqual("wifi", netOnWire("wifi"))
    XCTAssertEqual("carplay", surfaceOnWire("carplay"))
    XCTAssertEqual("ios", surfaceOnWire("ios"))
    XCTAssertEqual("android_auto", surfaceOnWire("android_auto"))
    XCTAssertEqual("browser", surfaceOnWire("browser"))
    XCTAssertNil(surfaceOnWire("pendant"))
    XCTAssertEqual("ios", surfaceHint(carAttached: false))
    XCTAssertEqual("carplay", surfaceHint(carAttached: true))
    XCTAssertNil(surfaceOnWire("android-auto"))
    XCTAssertNil(surfaceOnWire("car"))
    XCTAssertNil(surfaceOnWire("phone"))
    XCTAssertNil(surfaceOnWire("auto"))
    XCTAssertNil(surfaceOnWire("watch"))
  }

  func testCaptionAndPhotoTravelOnOneInbound() {
    let frame = inbound("this hatch?", id: "id-cap", context: nil, images: ["data:image/jpeg;base64,QQ"])
    let got = parseFrame(encodeFrame(frame))!
    XCTAssertEqual("this hatch?", got.text)
    XCTAssertEqual(["data:image/jpeg;base64,QQ"], got.images)
    XCTAssertEqual("inbound", got.kind)
  }

  func testPhotoOnlyInboundKeepsTheDataUrl() {
    let frame = inbound("", id: "id-2", context: nil, images: ["data:image/jpeg;base64,QQ"])
    let got = parseFrame(encodeFrame(frame))!
    XCTAssertEqual(["data:image/jpeg;base64,QQ"], got.images)
    XCTAssertEqual("inbound", got.kind)
    XCTAssertNil(got.text)
  }

  func testFaceFrameIsKeptForTheRev() {
    let got = parseFrame(#"{"kind":"face","text":"9"}"#)
    XCTAssertEqual("face", got?.kind)
    XCTAssertEqual("9", got?.text)
  }

  func testBackdropNoticeCarriesRevAndNoText() {
    let got = parseFrame(#"{"kind":"backdrop","rev":1725}"#)!
    XCTAssertEqual("backdrop", got.kind)
    XCTAssertEqual(1725, got.rev)
    XCTAssertNil(got.text)
    let cleared = parseFrame(#"{"kind":"backdrop","rev":0}"#)!
    XCTAssertEqual(0, cleared.rev)
    XCTAssertNil(parseFrame(#"{"kind":"backdrop","rev":-1}"#)?.rev)
  }

  func testThemeNoticeCarriesTheIdAndClearsOnNull() {
    let got = parseFrame(#"{"kind":"theme","theme":"noir"}"#)!
    XCTAssertEqual("theme", got.kind)
    XCTAssertEqual("noir", got.theme)
    XCTAssertNil(got.text)
    let cleared = parseFrame(#"{"kind":"theme","theme":null}"#)!
    XCTAssertEqual("", cleared.theme)
    XCTAssertNil(parseFrame(#"{"kind":"theme","theme":"nope"}"#)?.theme)
  }

  func testPinEncodesGeoWithoutText() {
    let raw = encodeFrame(pinFrame(PhoneContext(geo: Geo(lat: 1.0, lon: 2.0, accuracyM: 3.0))))
    XCTAssertTrue(raw.contains("\"kind\":\"pin\"") || raw.contains("\"kind\": \"pin\""))
    XCTAssertTrue(raw.contains("1"))
    XCTAssertFalse(raw.contains("\"text\""))
  }

  func testCmdsFrameCarriesTheCatalog() {
    let raw = #"{"kind":"cmds","commands":[{"name":"new","hint":"reset this session"}]}"#
    let got = parseFrame(raw)!
    XCTAssertEqual("cmds", got.kind)
    XCTAssertEqual("new", got.commands?.first?.name)
  }

  func testAckSinceIsTheReconnectCatchUp() {
    let got = parseFrame(encodeFrame(ackSince("abc")))
    XCTAssertEqual("ack", got?.kind)
    XCTAssertEqual("abc", got?.since)
  }

  func testMailboxSeqAndAtAreKeptAndJunkOrderDropped() {
    let got = parseFrame(#"{"text":"hi","id":"m1","seq":3,"at":1700000000000}"#)!
    XCTAssertEqual(3, got.seq)
    XCTAssertEqual(1_700_000_000_000, got.at)
    let junk = parseFrame(#"{"text":"hi","seq":0,"at":-1}"#)!
    XCTAssertNil(junk.seq)
    XCTAssertNil(junk.at)
    let encoded = encodeFrame(got)
    XCTAssertFalse(encoded.contains("\"seq\""))
    XCTAssertFalse(encoded.contains("\"at\":1700000000000"))
    XCTAssertNil(orderSeq("3"))
    XCTAssertNil(orderSeq(1.5))
    XCTAssertEqual(3, orderSeq(3))
    XCTAssertEqual(9, orderAt(9))
  }

  func testKitReplyAndCronAreSpokenInTheCar() {
    XCTAssertTrue(shouldSpeak("reply"))
    XCTAssertTrue(shouldSpeak("push"))
    XCTAssertFalse(shouldSpeak("ack"))
    XCTAssertFalse(shouldSpeak("inbound"))
    XCTAssertFalse(shouldSpeak("reply", replay: true))
    XCTAssertFalse(shouldSpeak("push", replay: true))
    let live = parseFrame(#"{"kind":"reply","text":"hi"}"#)!
    XCTAssertFalse(live.replay)
    XCTAssertTrue(shouldSpeak(live.kind, replay: live.replay))
    let replayed = parseFrame(#"{"kind":"reply","text":"hi","replay":true}"#)!
    XCTAssertTrue(replayed.replay)
    XCTAssertFalse(shouldSpeak(replayed.kind, replay: replayed.replay))
    XCTAssertFalse(encodeFrame(replayed).contains("replay"))
  }

  func testJunkAndKeepaliveAreDropped() {
    XCTAssertNil(parseFrame("nope"))
    XCTAssertNil(parseFrame("ping"))
    XCTAssertNil(parseFrame("pong"))
  }

  func testInboundOmitsEmptyTextAndKeepsPhotos() {
    let frame = inbound("", id: "id-2", context: nil, images: ["data:image/jpeg;base64,aa", "https://x/b.jpg"])
    let raw = encodeFrame(frame)
    let got = parseFrame(raw)!
    XCTAssertNil(got.text)
    XCTAssertEqual(["data:image/jpeg;base64,aa", "https://x/b.jpg"], got.images)
  }

  func testEmptyImagesAndEmptyContextStayOffTheWire() {
    let raw = encodeFrame(inbound("hi", id: "id-3", context: PhoneContext(), images: []))
    XCTAssertFalse(raw.contains("images"))
    XCTAssertFalse(raw.contains("context"))
  }

  func testPinFrameCarriesGeoWithoutAccuracy() {
    let raw = encodeFrame(pinFrame(PhoneContext(geo: Geo(lat: 1.0, lon: 2.0))))
    let got = parseFrame(raw)!
    XCTAssertEqual("pin", got.kind)
    XCTAssertTrue(raw.contains("\"lat\":1") || raw.contains("\"lat\": 1"))
    XCTAssertFalse(raw.contains("accuracy_m"))
  }

  func testCmdsCatalogIsParsedAndJunkDropped() {
    let got = parseFrame(
      #"{"kind":"cmds","commands":[{"name":"NEW","hint":"reset this session","args":true},{"name":"nope"}]}"#
    )!
    XCTAssertEqual("cmds", got.kind)
    XCTAssertEqual([SlashCommand(name: "new", hint: "reset this session", args: true)], got.commands)
  }

  func testBlankImageUrlsAndEmptyStringsAreDropped() {
    let got = parseFrame(#"{"text":"","kind":"","images":[{},{"url":""},{"url":"https://a"}]}"#)!
    XCTAssertNil(got.text)
    XCTAssertNil(got.kind)
    XCTAssertEqual(["https://a"], got.images)
  }

  func testInboundTextIsCapped() {
    let t = String(repeating: "x", count: textCharsMax + 40)
    let got = parseFrame("{\"kind\":\"reply\",\"text\":\"\(t)\"}")!
    XCTAssertEqual(textCharsMax, got.text!.count)
  }

  func testInboundTextIsCappedByUtf8Bytes() {
    let t = String(repeating: "é", count: (textBytesMax / 2) + 4)
    let got = capUtf8(t)
    XCTAssertTrue(Array(got.utf8).count <= textBytesMax)
    XCTAssertTrue(got.count < t.count)
  }

  func testNotifyBodyPrefersTextThenPhotoThenPing() {
    XCTAssertEqual("hi", notifyBody(" hi ", hasPhoto: true))
    XCTAssertEqual("Photo", notifyBody("  ", hasPhoto: true))
    XCTAssertEqual("ping", notifyBody(nil, hasPhoto: false))
  }

  func testBatteryAndNetHintsMatchTheWire() {
    XCTAssertEqual(BatteryHint(pct: 1, charging: false), batteryHint(pct: 1, charging: false))
    XCTAssertNil(batteryHint(pct: -1, charging: false))
    XCTAssertNil(batteryHint(pct: 101, charging: true))
    XCTAssertEqual("wifi", netHint(wifi: true, cellular: true))
    XCTAssertEqual("cellular", netHint(wifi: false, cellular: true))
    XCTAssertEqual("unknown", netHint(wifi: false, cellular: false))
    XCTAssertEqual(BatteryHint(pct: 80, charging: true), batteryHintFromLevel(0.8, charging: true))
    XCTAssertEqual(BatteryHint(pct: 100, charging: false), batteryHintFromLevel(0.995, charging: false))
    XCTAssertNil(batteryHintFromLevel(-1, charging: false))
  }

  func testInboundImagesRejectOversizeDataAndLongHttp() {
    let huge = "data:image/jpeg;base64," + String(repeating: "A", count: 2_100_000)
    XCTAssertFalse(acceptInboundImage(huge))
    let longHttp = "https://x/" + String(repeating: "a", count: 3_000)
    XCTAssertFalse(acceptInboundImage(longHttp))
    XCTAssertTrue(acceptInboundImage("https://example.test/a.jpg"))
    XCTAssertFalse(acceptInboundImage("http://example.test/a.jpg"))
  }
}
