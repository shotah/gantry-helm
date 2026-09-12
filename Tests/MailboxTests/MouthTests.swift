import XCTest
@testable import Mailbox

final class MouthTests: XCTestCase {
  func testFaceFrameUpdatesRevAndSkipsTheThread() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "face", text: "7"))
    XCTAssertEqual(7, mouth.avatarRev)
    XCTAssertTrue(mouth.lines.isEmpty)
  }

  func testBackdropNoticeSetsRevIncludingZeroAndNeverABubble() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "backdrop", text: "1725", rev: 1725))
    XCTAssertEqual(1725, mouth.backdropRev)
    XCTAssertTrue(mouth.lines.isEmpty)
    mouth.ingest(WireFrame(kind: "backdrop", rev: 0))
    XCTAssertEqual(0, mouth.backdropRev)
    XCTAssertTrue(mouth.lines.isEmpty)
    mouth.ingest(WireFrame(kind: "backdrop"))
    XCTAssertEqual(0, mouth.backdropRev)
  }

  func testThemeNoticeSetsTheRoomIdAndClearsOnEmpty() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "theme", theme: "noir"))
    XCTAssertEqual("noir", mouth.roomTheme)
    XCTAssertTrue(mouth.lines.isEmpty)
    mouth.ingest(WireFrame(kind: "theme", theme: ""))
    XCTAssertEqual("", mouth.roomTheme)
    mouth.ingest(WireFrame(kind: "theme", theme: "nope"))
    XCTAssertEqual("", mouth.roomTheme)
  }

  func testCmdsReplaceTheCatalog() {
    let mouth = Mouth()
    let cmds = [SlashCommand(name: "new", hint: "reset this session")]
    mouth.ingest(WireFrame(kind: "cmds", commands: cmds))
    XCTAssertEqual(cmds, mouth.catalog)
    mouth.replace(lines: [ChatLine(id: "1", fromYou: true, text: "hi", kind: "inbound")], up: true, hint: "ok")
    XCTAssertEqual([], mouth.catalog)
    XCTAssertEqual(true, mouth.up)
    XCTAssertEqual(0, mouth.typingUntil)
  }

  func testSilentKindsStayOffTheThread() {
    let mouth = Mouth()
    for kind in ["ack", "allow", "pin"] {
      mouth.ingest(WireFrame(kind: kind, text: "nope"))
    }
    XCTAssertTrue(mouth.lines.isEmpty)
    XCTAssertEqual(0, mouth.typingUntil)
  }

  func testMailboxErrorIsAHintNotABubble() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "error", text: "bad frame"))
    XCTAssertTrue(mouth.lines.isEmpty)
    XCTAssertEqual("bad frame", mouth.hint)
  }

  func testMailboxErrorMarksTheRefusedBubbleById() {
    let mouth = Mouth()
    mouth.add(ChatLine(id: "a1", fromYou: true, text: "hatch?", kind: "inbound", pending: true))
    mouth.add(
      ChatLine(
        id: "a2", fromYou: true, text: "photo", kind: "inbound",
        photo: "data:image/jpeg;base64,aa", pending: true
      )
    )
    mouth.ingest(WireFrame(kind: "typing"))
    XCTAssertEqual(false, mouth.ingest(WireFrame(kind: "error", id: "a2", text: "too large")))
    XCTAssertTrue(mouth.lines[0].pending)
    XCTAssertNil(mouth.lines[0].failed)
    XCTAssertFalse(mouth.lines[1].pending)
    XCTAssertEqual("Not sent — too big for the room.", mouth.lines[1].failed)
    XCTAssertEqual(2, mouth.lines.count)
    XCTAssertEqual("", mouth.hint)
    XCTAssertEqual(0, mouth.typingUntil)
  }

  func testMailboxErrorWithoutAnIdFallsBackToYourNewestPendingBubble() {
    let mouth = Mouth()
    mouth.add(ChatLine(id: "a1", fromYou: true, text: "one", kind: "inbound", pending: true))
    mouth.add(ChatLine(id: "a2", fromYou: true, text: "two", kind: "inbound", pending: true))
    mouth.add(ChatLine(id: "k1", fromYou: false, text: "kit", kind: "reply"))
    mouth.ingest(WireFrame(kind: "error", text: "rate"))
    XCTAssertEqual([true, false, false], mouth.lines.map(\.pending))
    XCTAssertEqual(
      [nil, "Not sent — too much too fast. Wait a minute, then try again.", nil],
      mouth.lines.map(\.failed)
    )
    XCTAssertEqual("", mouth.hint)
  }

  func testWorkerRefusalPayloadLandsOnTheRefusedPhotoBubble() {
    let mouth = Mouth()
    mouth.add(
      ChatLine(
        id: "msg-1", fromYou: true, text: "", kind: "inbound",
        photo: "data:image/jpeg;base64,aa", pending: true
      )
    )
    let frame = parseFrame(#"{"kind":"error","text":"too large","id":"msg-1"}"#)!
    XCTAssertFalse(mouth.ingest(frame))
    let line = mouth.lines[0]
    XCTAssertEqual("Not sent — too big for the room.", line.failed)
    XCTAssertFalse(line.pending)
    XCTAssertEqual(true, line.fromYou)
    XCTAssertFalse(movesCursor(frame.kind))
  }

  func testMailboxErrorNeverMarksACraneBubble() {
    let mouth = Mouth()
    mouth.add(ChatLine(id: "k1", fromYou: false, text: "kit", kind: "reply"))
    mouth.ingest(WireFrame(kind: "error", id: "k1", text: "rate"))
    XCTAssertNil(mouth.lines[0].failed)
    XCTAssertEqual("rate", mouth.hint)
    XCTAssertFalse(mouth.fail(id: "nope", why: "why"))
  }

  func testEmptyTextDropsUnlessItIsAPingOrPhoto() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "reply", text: "  "))
    XCTAssertTrue(mouth.lines.isEmpty)
    mouth.ingest(WireFrame(kind: "push"))
    XCTAssertEqual("(ping)", mouth.lines[0].text)
    mouth.ingest(WireFrame(kind: "reply", id: "p", images: ["data:image/jpeg;base64,aa"]))
    XCTAssertEqual("", mouth.lines.last?.text)
    XCTAssertEqual("data:image/jpeg;base64,aa", mouth.lines.last?.photo)
  }

  func testInboundIsFromYouAndAddCapsAtEighty() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "inbound", id: "1", text: "hi"))
    XCTAssertEqual(true, mouth.lines[0].fromYou)
    mouth.setUp(true)
    mouth.setHint("live")
    mouth.setFaceHint("bad jpeg")
    mouth.setAvatarRev(2)
    XCTAssertEqual("live", mouth.hint)
    XCTAssertEqual("bad jpeg", mouth.faceHint)
    for i in 0..<90 {
      mouth.add(ChatLine(id: "\(i)", fromYou: false, text: "n\(i)", kind: "reply"))
    }
    XCTAssertEqual(80, mouth.lines.count)
    XCTAssertEqual("n10", mouth.lines.first?.text)
  }

  func testTranscriptReplayPaintsAndDedupesById() {
    let mouth = Mouth()
    XCTAssertTrue(mouth.ingest(WireFrame(kind: "inbound", id: "a", text: "hatch", seq: 1, at: 10, replay: true)))
    XCTAssertTrue(mouth.ingest(WireFrame(kind: "reply", id: "b", text: "latched", seq: 2, at: 20, replay: true)))
    XCTAssertFalse(mouth.ingest(WireFrame(kind: "reply", id: "b", text: "latched", seq: 2, at: 20, replay: true)))
    XCTAssertEqual(["hatch", "latched"], mouth.lines.map(\.text))
  }

  func testDraftReplacesInPlaceAndBlankClears() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "draft", text: "Gate"))
    mouth.ingest(WireFrame(kind: "draft", text: "Gate's on the latch"))
    XCTAssertEqual(1, mouth.lines.count)
    let draft = mouth.lines[0]
    XCTAssertEqual(draftId, draft.id)
    XCTAssertEqual(false, draft.fromYou)
    XCTAssertEqual("draft", draft.kind)
    XCTAssertEqual("Gate's on the latch", draft.text)
    mouth.ingest(WireFrame(kind: "draft", text: "  "))
    XCTAssertTrue(mouth.lines.isEmpty)
  }

  func testReplyClearsTheDraftBubble() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "draft", text: "⏳…"))
    mouth.ingest(WireFrame(kind: "reply", id: "r1", text: "Gate's on the latch until 21:00."))
    XCTAssertEqual(1, mouth.lines.count)
    XCTAssertEqual("r1", mouth.lines[0].id)
    XCTAssertEqual("reply", mouth.lines[0].kind)
  }

  func testDraftToReplyKeepsTheLiveComposeKey() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "draft", text: "Hello"))
    let draft = mouth.lines[0]
    XCTAssertEqual(true, draft.live)
    XCTAssertEqual(liveComposeKey, composeKey(draft))
    mouth.ingest(WireFrame(kind: "reply", id: "r1", text: "Hello"))
    let reply = mouth.lines[0]
    XCTAssertEqual("r1", reply.id)
    XCTAssertEqual(true, reply.live)
    XCTAssertEqual(liveComposeKey, composeKey(reply))
    mouth.ingest(WireFrame(kind: "inbound", id: "a1", text: "thanks"))
    XCTAssertEqual(false, mouth.lines.first { $0.id == "r1" }?.live)
    XCTAssertEqual("r1", composeKey(mouth.lines.first { $0.id == "r1" }!))
    mouth.ingest(WireFrame(kind: "draft", text: "Next"))
    XCTAssertEqual(false, mouth.lines.first { $0.id == "r1" }?.live)
    XCTAssertEqual(liveComposeKey, composeKey(mouth.lines.first { $0.id == draftId }!))
  }

  func testEmptyReplyStillDropsTheDraft() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "draft", text: "⏳…"))
    mouth.ingest(WireFrame(kind: "reply", text: "  "))
    XCTAssertTrue(mouth.lines.isEmpty)
  }

  func testSocketDownDropsDraftAndTyping() {
    var t: Int64 = 1_000
    let mouth = Mouth(now: { t })
    mouth.setUp(true)
    mouth.ingest(WireFrame(kind: "draft", text: "⏳…"))
    mouth.ingest(WireFrame(kind: "typing"))
    XCTAssertEqual(1, mouth.lines.count)
    XCTAssertEqual(t + typingTtlMs, mouth.typingUntil)
    mouth.setUp(false)
    XCTAssertTrue(mouth.lines.isEmpty)
    XCTAssertEqual(0, mouth.typingUntil)
    XCTAssertFalse(mouth.up)
  }

  func testDraftStaysLastPastTheEightyCap() {
    let mouth = Mouth()
    for i in 0..<80 {
      mouth.add(ChatLine(id: "\(i)", fromYou: false, text: "n\(i)", kind: "reply"))
    }
    mouth.ingest(WireFrame(kind: "draft", text: "live"))
    XCTAssertEqual(80, mouth.lines.count)
    XCTAssertEqual(draftId, mouth.lines.last?.id)
    XCTAssertEqual("live", mouth.lines.last?.text)
    XCTAssertEqual("n1", mouth.lines.first?.text)
  }

  func testTypingTtlAndClearingKinds() {
    var t: Int64 = 10_000
    let mouth = Mouth(now: { t })
    mouth.ingest(WireFrame(kind: "typing"))
    XCTAssertEqual(16_000, mouth.typingUntil)
    t = 12_000
    mouth.ingest(WireFrame(kind: "typing"))
    XCTAssertEqual(18_000, mouth.typingUntil)
    mouth.ingest(WireFrame(kind: "ack", id: "a1"))
    XCTAssertEqual(18_000, mouth.typingUntil)
    mouth.ingest(WireFrame(kind: "reply", id: "r1", text: "done"))
    XCTAssertEqual(0, mouth.typingUntil)
    mouth.ingest(WireFrame(kind: "typing"))
    XCTAssertEqual(18_000, mouth.typingUntil)
    mouth.ingest(WireFrame(kind: "push", text: "20:40"))
    XCTAssertEqual(0, mouth.typingUntil)
    mouth.ingest(WireFrame(kind: "typing"))
    mouth.ingest(WireFrame(kind: "error", text: "rate"))
    XCTAssertEqual(0, mouth.typingUntil)
    XCTAssertTrue(clearsTyping("reply"))
    XCTAssertTrue(clearsTyping("push"))
    XCTAssertTrue(clearsTyping("error"))
    XCTAssertFalse(clearsTyping("ack"))
    XCTAssertFalse(clearsTyping("draft"))
  }

  func testPushClearsTypingButLeavesTheDraft() {
    let mouth = Mouth(now: { 1 })
    mouth.ingest(WireFrame(kind: "draft", text: "⏳…"))
    mouth.ingest(WireFrame(kind: "typing"))
    mouth.ingest(WireFrame(kind: "push", text: "still on the dock?"))
    XCTAssertEqual(0, mouth.typingUntil)
    XCTAssertEqual(draftId, mouth.lines.last?.id)
    XCTAssertEqual("push", mouth.lines.first?.kind)
  }

  func testAckClearsPendingOnTheMatchingBubble() {
    let mouth = Mouth()
    mouth.add(ChatLine(id: "a1", fromYou: true, text: "hi", kind: "inbound", pending: true))
    mouth.ingest(WireFrame(kind: "ack", id: "nope"))
    XCTAssertTrue(mouth.lines[0].pending)
    mouth.ingest(WireFrame(kind: "ack", id: "a1"))
    XCTAssertFalse(mouth.lines[0].pending)
  }

  func testCatchUpPaintsBySeqAndKeepsADraftLast() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "reply", id: "b", text: "second", seq: 2, at: 20))
    mouth.ingest(WireFrame(kind: "reply", id: "a", text: "first", seq: 1, at: 10))
    XCTAssertEqual(["a", "b"], mouth.lines.map(\.id))
    mouth.ingest(WireFrame(kind: "draft", text: "⏳ spinning up"))
    mouth.ingest(WireFrame(kind: "inbound", id: "late", text: "I already sent this", seq: 3, at: 15))
    XCTAssertEqual(["a", "b", "late", draftId], mouth.lines.map(\.id))
    let restamp = mouth.ingest(WireFrame(kind: "reply", id: "b", text: "second", seq: 2, at: 20))
    XCTAssertEqual(false, restamp)
    XCTAssertEqual(4, mouth.lines.count)
  }

  func testHydrateMergesByIdInMailboxOrderAndSkipsDrafts() {
    let mouth = Mouth()
    mouth.ingest(WireFrame(kind: "reply", id: "live", text: "fresh", seq: 3, at: 30))
    mouth.hydrate([
      ChatLine(id: "a", fromYou: true, text: "old me", kind: "inbound", at: 10, seq: 1),
      ChatLine(id: "live", fromYou: false, text: "stale copy", kind: "reply", at: 30, seq: 3),
      ChatLine(id: draftId, fromYou: false, text: "…", kind: "draft", at: 99),
      ChatLine(id: "b", fromYou: false, text: "old kit", kind: "reply", at: 20, seq: 2),
    ])
    XCTAssertEqual(["a", "b", "live"], mouth.lines.map(\.id))
    XCTAssertEqual("fresh", mouth.lines.last?.text)
    mouth.hydrate([])
    XCTAssertEqual(3, mouth.lines.count)
  }

  func testHydrateStaysUnderTheCap() {
    let mouth = Mouth()
    mouth.add(ChatLine(id: "now", fromYou: false, text: "now", kind: "reply", at: 1_000))
    mouth.hydrate((0..<100).map { ChatLine(id: "c\($0)", fromYou: false, text: "n\($0)", kind: "reply", at: Int64($0)) })
    XCTAssertEqual(80, mouth.lines.count)
    XCTAssertEqual("now", mouth.lines.last?.id)
    XCTAssertEqual("c21", mouth.lines.first?.id)
  }

  func testClearThreadDropsBubblesOnlyAndHydrateRefillsIt() {
    let mouth = Mouth()
    mouth.setUp(true)
    mouth.setHint("live")
    mouth.setRoomTheme("noir")
    mouth.add(ChatLine(id: "k1", fromYou: false, text: "kit", kind: "reply"))
    mouth.clearThread()
    XCTAssertTrue(mouth.lines.isEmpty)
    XCTAssertTrue(mouth.up)
    XCTAssertEqual("live", mouth.hint)
    XCTAssertEqual("noir", mouth.roomTheme)
    mouth.hydrate([ChatLine(id: "c1", fromYou: false, text: "cached", kind: "reply", at: 1)])
    XCTAssertEqual(["c1"], mouth.lines.map(\.id))
  }

  func testEchoRestampKeepsPendingUntilAck() {
    let mouth = Mouth()
    mouth.add(ChatLine(id: "a1", fromYou: true, text: "hi", kind: "inbound", pending: true, at: 50))
    XCTAssertEqual(false, mouth.ingest(WireFrame(kind: "inbound", id: "a1", text: "hi", seq: 4, at: 40)))
    let line = mouth.lines[0]
    XCTAssertEqual(4, line.seq)
    XCTAssertEqual(40, line.at)
    XCTAssertEqual(true, line.pending)
    mouth.ingest(WireFrame(kind: "ack", id: "a1"))
    XCTAssertEqual(false, mouth.lines[0].pending)
  }
}
