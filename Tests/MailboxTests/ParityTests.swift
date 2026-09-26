import XCTest
@testable import Mailbox

final class ParityTests: XCTestCase {
  func testAimsDropsABadRowAndAHalfFormedBlockButKeepsTheBoard() {
    let raw = """
    {"kind":"aims","aims":[
      {"area":"Nope","sentence":"no","rating30":1,"sum7":0,"streak":0,"note":"","days":[]},
      {"area":"training","sentence":"Lift.","rating30":1.4,"sum7":6,"streak":2,"note":"asked",
       "days":[{"day":"2026-09-01","score":1,"events":[4]},{"day":"bad","score":1}],
       "slope":0.3,
       "block":{"days":10,"up":4,"against":6,"mean":0.2},
       "effect":{"a":"training","b":"sleep","metric":"weight","r":-0.42,"n":9}},
      {"area":"sleep","sentence":"In bed.","rating30":-0.4,"sum7":-1,"streak":0,"note":"quiet","days":[]}
    ],"links":[
      {"a":"training","b":"training","r":0.2,"n":3},
      {"a":"training","b":"sleep","r":0.38,"n":12}
    ]}
    """
    let frame = parseFrame(raw)!
    XCTAssertEqual("aims", frame.kind)
    XCTAssertEqual(2, frame.aims?.aims.count)
    let training = frame.aims!.aims[0]
    XCTAssertEqual("training", training.area)
    XCTAssertNil(training.block)
    XCTAssertEqual("weight", training.effect?.metric)
    XCTAssertEqual(1, training.days.count)
    XCTAssertEqual("training → next-day sleep r +0.38 (n 12)", linkLine(frame.aims!.links[0]))
    XCTAssertEqual("30d +1.4 · 7d +6 · streak 2 · asked", statsLine(training))
    XCTAssertEqual("slope +0.3/wk · weight r -0.42 (n 9)", trendLine(training))
    XCTAssertFalse(movesCursor("aims"))
  }

  func testEmptyAimsClearsAndAMissingArrayIsJunk() {
    let mouth = Mouth()
    mouth.ingest(parseFrame(#"{"kind":"aims","aims":[{"area":"training","sentence":"Lift.","rating30":0,"sum7":0,"streak":0,"note":"","days":[]}]}"#)!)
    XCTAssertEqual(1, mouth.aims.aims.count)
    XCTAssertTrue(mouth.lines.isEmpty)
    mouth.ingest(parseFrame(#"{"kind":"aims","text":"nope"}"#)!)
    XCTAssertEqual(1, mouth.aims.aims.count)
    mouth.ingest(parseFrame(#"{"kind":"aims","aims":[]}"#)!)
    XCTAssertTrue(mouth.aims.isEmpty)
    XCTAssertNil(parseAims(["kind": "aims"]))
  }

  func testGoalsBadgeCountsChangesNotTheBoardSize() {
    let board = parseFrame(
      #"{"kind":"aims","aims":[{"area":"training","sentence":"Lift.","rating30":1,"sum7":1,"streak":1,"note":"","days":[]}]}"#
    )!.aims!
    XCTAssertEqual(1, changedAims(board, seen: [:]))
    XCTAssertEqual("goals (1)", goalsLabel(1))
    XCTAssertEqual("goals", goalsLabel(0))
    let seen = seenAims(board)
    XCTAssertEqual(0, changedAims(board, seen: seen))
    XCTAssertEqual(seen, parseSeenAims(encodeSeenAims(seen)))
    XCTAssertEqual("/aims training", askAim("training"))
    XCTAssertEqual(0.45, dayWeight(1), accuracy: 0.001)
  }

  func testReactPaintsAChipAndDoesNotTakeATurn() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "reply", text: "leave by 8", id: "r1"))
    XCTAssertFalse(mouth.ingest(WireFrame(kind: "react", text: "👍", id: "r1")))
    XCTAssertEqual("👍", mouth.lines[0].reaction)
    XCTAssertTrue(mouth.lines.count == 1)
    XCTAssertFalse(mouth.ingest(WireFrame(kind: "react", text: " \u{0001} ", id: "r1")))
    XCTAssertEqual("👍", mouth.lines[0].reaction)
    XCTAssertFalse(mouth.applyReaction(id: "missing", text: "🔥"))
    XCTAssertEqual("", toggleReaction("👍", "👍"))
    XCTAssertEqual("🔥", toggleReaction("👍", "🔥"))
    XCTAssertTrue(canReact(fromYou: false, kind: "reply", id: "r1"))
    XCTAssertFalse(canReact(fromYou: true, kind: "inbound", id: "r1"))
    XCTAssertFalse(movesCursor("react"))
    let raw = encodeFrame(reactFrame(id: "r1", text: "🔥"))
    XCTAssertTrue(raw.contains("react"))
    XCTAssertTrue(raw.contains("🔥"))
  }

  func testSeenAckIsTrueOnlyAndDismissesASiblingRead() {
    XCTAssertEqual(true, parseSeen(true))
    XCTAssertNil(parseSeen(false))
    XCTAssertNil(parseSeen("true"))
    let bare = encodeFrame(ackSeen())
    XCTAssertTrue(bare.contains("\"seen\":true") || bare.contains("\"seen\": true"))
    XCTAssertFalse(bare.contains("since"))
    let named = ackSeen("r1")
    XCTAssertEqual("r1", named.id)
    XCTAssertEqual(true, named.seen)
    XCTAssertTrue(dismissKitOnFrame(kind: "ack", replay: false, fresh: false, seen: true))
    XCTAssertTrue(dismissKitOnFrame(kind: "inbound", replay: false, fresh: true, seen: nil))
    XCTAssertFalse(dismissKitOnFrame(kind: "inbound", replay: true, fresh: true, seen: nil))
    XCTAssertFalse(dismissKitOnFrame(kind: "ack", replay: false, fresh: false, seen: nil))
    XCTAssertFalse(encodeFrame(ackSince("3")).contains("seen"))
    XCTAssertTrue(encodeFrame(ackSince("3", seen: true)).contains("seen"))
  }

  func testSpokenInputRidesTheContext() {
    let raw = encodeFrame(inbound("on the dock", id: "v1", context: PhoneContext(input: inputHint(spoken: true))))
    XCTAssertTrue(raw.contains("spoken"))
    XCTAssertNil(inputOnWire("typed"))
    XCTAssertNil(inputHint(spoken: false))
  }

  func testSpeakableMatchesThePocketReader() {
    XCTAssertEqual("Bold and soft and also soft", speakable("**Bold** and *soft* and _also soft_"))
    XCTAssertEqual("Tonight\nRain after 8.", speakable("## Tonight\nRain after 8."))
    XCTAssertEqual("code", speakable("```\nx\n```"))
    XCTAssertEqual("photo", speakable("![the hatch](data:image/jpeg;base64,/9j/)"))
    XCTAssertEqual("See the map now", speakable("See [the map](https://maps.example/x) now"))
    XCTAssertEqual("milk\neggs\nfirst\nsecond", speakable("- milk\n- eggs\n\n1. first\n2. second"))
    XCTAssertEqual("On my way see you soon", speakable("On my way 🚗💨 see you soon ❤️"))
    XCTAssertEqual("", speakable("---"))
    XCTAssertEqual("Kit said\nno.", speakable("> Kit said\n> no."))
    XCTAssertEqual("Hi there.", clipForSpeech("Hi there."))
    XCTAssertTrue(isEmojiPart(0x1F697))
    XCTAssertFalse(isEmojiPart(UInt32(UnicodeScalar("a").value)))
  }

  func testSpokenFoldsAGrowingHypothesis() {
    XCTAssertEqual("well I can send", spokenFrom(["well", "well I", "well I can send"]))
    XCTAssertEqual("well I can send this", spokenFrom(["well I can send"], interim: "this"))
    let said = Utterance { _ in }
    said.partial("on the")
    said.final("on the dock")
    XCTAssertEqual("on the dock", said.heard)
    var got = ""
    let done = Utterance { got = $0 }
    done.final("leave")
    done.abort()
    XCTAssertEqual("", got)
    XCTAssertEqual("Hold to talk", holdLabel(.idle))
    XCTAssertEqual("Mic blocked", holdLabel(.blocked))
  }

  func testVoiceGateAndLanguage() {
    XCTAssertTrue(speaksReply(kind: "reply", replay: false, fresh: true, armed: true))
    XCTAssertFalse(speaksReply(kind: "push", replay: false, fresh: true, armed: true))
    XCTAssertFalse(speaksReply(kind: "reply", replay: true, fresh: true, armed: true))
    XCTAssertTrue(disarmsVoice("error"))
    XCTAssertTrue(voiceBarShown(offered: true, on: true))
    XCTAssertFalse(voiceBarShown(offered: false, on: true))
    XCTAssertEqual("Live · voice…", threadStatusLine(up: true, hint: "Live", typingUntil: 9, nowMs: 1, speak: .fetching))
    XCTAssertEqual("Live · speaking", threadStatusLine(up: true, hint: "", typingUntil: 0, nowMs: 1, speak: .playing))
    XCTAssertEqual("ja-JP", speechLang("ja"))
    XCTAssertEqual("en", parseLang("nope"))
    XCTAssertEqual("Kit's voice is off on this Worker (no TTS key, or VOICE=off).", speakFailHint(.noVoice))
    XCTAssertEqual(.noVoice, speakFailFromStatus(404))
    XCTAssertEqual(.unauthorized, speakFailFromStatus(401))
  }

  func testTtsPostsTextAndLang() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data([0xFF, 0xFB]))]
    let api = TtsApi(transport: http)
    guard case .ok(let bytes) = api.synthesize(origin: "http://mailbox.test/", bearer: "jwe", text: "hi", lang: "ja") else {
      return XCTFail("expected mp3")
    }
    XCTAssertEqual(2, bytes.count)
    XCTAssertEqual("/api/tts", http.requests[0].url?.path)
    let body = String(data: http.requests[0].httpBody ?? Data(), encoding: .utf8) ?? ""
    XCTAssertTrue(body.contains("hi"))
    XCTAssertTrue(body.contains("ja"))
    XCTAssertEqual("Bearer jwe", http.requests[0].value(forHTTPHeaderField: "Authorization"))
    http.queue = [HTTPResult(status: 404, body: Data())]
    XCTAssertEqual(.err(.noVoice), api.synthesize(origin: "http://mailbox.test/", bearer: "jwe", text: "hi"))
  }

  func testConfigReadsVoice() {
    XCTAssertEqual(true, parseAuthConfig(#"{"mode":"google","google":true,"voice":true}"#).voice)
    XCTAssertEqual(false, parseAuthConfig(#"{"mode":"google","google":true}"#).voice)
  }
}
