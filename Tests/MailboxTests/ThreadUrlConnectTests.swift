import XCTest
@testable import Mailbox

private struct Bubble: ThreadOrder {
  var id: String
  var at: Int64
  var seq: Int?
  var kind: String?
}

final class ThreadTests: XCTestCase {
  func testCursorOfIsTheHighestStampedSeqNotLastArrival() {
    XCTAssertEqual(ThreadCursor(), cursorOf([Bubble]()))
    XCTAssertEqual(ThreadCursor(), cursorOf([Bubble(id: "sending", at: 5), Bubble(id: "refused", at: 6)]))
    let cur = cursorOf([
      Bubble(id: "a", at: 10, seq: 4),
      Bubble(id: "late", at: 5, seq: 2),
      Bubble(id: "me", at: 20),
      Bubble(id: "b", at: 30, seq: 9),
    ])
    XCTAssertEqual(ThreadCursor(id: "b", seq: 9), cur)
    XCTAssertEqual("9", ackSince(cur))
  }

  func testCapThreadKeepsTheNewest() {
    XCTAssertEqual([2, 3], capThread([1, 2, 3], max: 2))
    XCTAssertEqual([1, 2], capThread([1, 2], max: 5))
  }

  func testRememberSeenDropsOldestIdsFirst() {
    var seen = ["a", "b", "c"]
    rememberSeen(&seen, id: "d", max: 3)
    XCTAssertEqual(["b", "c", "d"], seen)
  }

  func testPlaceInThreadInsertsCatchUpBySeqAndKeepsADraftLast() {
    let late = Bubble(id: "b", at: 20, seq: 2)
    let early = Bubble(id: "a", at: 10, seq: 1)
    let draft = Bubble(id: "__draft__", at: 1, kind: "draft")
    let ordered = placeInThread(placeInThread([late], early), draft)
    XCTAssertEqual(["a", "b", "__draft__"], ordered.map(\.id))
    let pending = placeInThread(
      [Bubble(id: "mine", at: 50)],
      Bubble(id: "missed", at: 40, seq: 4)
    )
    XCTAssertEqual(["missed", "mine"], pending.map(\.id))
  }

  func testOnlyQueuedTurnsMoveTheCursor() {
    XCTAssertEqual(true, movesCursor("reply"))
    XCTAssertEqual(true, movesCursor("inbound"))
    XCTAssertEqual(true, movesCursor("push"))
    XCTAssertEqual(true, movesCursor(nil))
    XCTAssertEqual(false, movesCursor("ack"))
    XCTAssertEqual(false, movesCursor("error"))
    XCTAssertEqual(false, movesCursor("face"))
    XCTAssertEqual(false, movesCursor("backdrop"))
    XCTAssertEqual(false, movesCursor("theme"))
  }

  func testAckSinceUsesTheHighestSeqNotLastArrival() {
    var cur = advanceCursor(ThreadCursor(seq: 0), id: "b", seq: 2)
    cur = advanceCursor(cur, id: "a", seq: 1)
    XCTAssertEqual("2", ackSince(cur))
    XCTAssertEqual("legacy", ackSince(ThreadCursor(id: "legacy", seq: 0)))
    XCTAssertNil(ackSince(ThreadCursor()))
  }
}

final class MailboxUrlTests: XCTestCase {
  func testHttpsOriginBecomesWssPhoneSocket() {
    XCTAssertEqual(
      "wss://gantry-pendant.example.workers.dev/ws/kit?role=phone",
      mailboxUrl("https://gantry-pendant.example.workers.dev", slug: "kit")
    )
  }

  func testSimulatorLoopbackIsWs() {
    XCTAssertEqual(
      "ws://127.0.0.1:3000/ws/kit?role=phone",
      mailboxUrl("http://127.0.0.1:3000/", slug: "kit")
    )
  }

  func testSlugRulesMatchTheWorker() {
    XCTAssertEqual("kit", parseSlug("Kit"))
    XCTAssertEqual("kit-2", parseSlug("  KIT-2  "))
    XCTAssertNil(parseSlug("1kit"))
    XCTAssertNil(parseSlug(""))
    XCTAssertNil(parseSlug(String(repeating: "a", count: 33)))
  }

  func testHostWithoutSchemeIsWss() {
    XCTAssertEqual(
      "wss://gantry-pendant.example.workers.dev/ws/kit?role=crane",
      mailboxUrl("gantry-pendant.example.workers.dev/", slug: "kit", role: "crane")
    )
  }

  func testHttpOriginTrimsSlash() {
    XCTAssertEqual("http://10.0.2.2:3000", httpOrigin("  http://10.0.2.2:3000/  "))
  }

  func testNormalizeMailboxOriginAcceptsWorkerAndCraneUrls() {
    XCTAssertEqual("https://pendant.example.com", normalizeMailboxOrigin("https://pendant.example.com/"))
    XCTAssertEqual("https://pendant.example.com", normalizeMailboxOrigin("https://pendant.example.com/ws/kit"))
    XCTAssertEqual("https://pendant.example.com", normalizeMailboxOrigin("wss://pendant.example.com/ws/kit"))
    XCTAssertEqual("http://10.0.2.2:3000", normalizeMailboxOrigin("ws://10.0.2.2:3000/ws/kit"))
    XCTAssertEqual(
      "https://gantry-pendant.example.workers.dev",
      normalizeMailboxOrigin("gantry-pendant.example.workers.dev")
    )
    XCTAssertEqual("http://10.0.2.2:3000", normalizeMailboxOrigin("http://10.0.2.2:3000"))
  }
}

final class MailboxConnectTests: XCTestCase {
  func testConnectNeedsASlugAndABearer() {
    XCTAssertEqual("Talking to needs a crane slug like kit.", mailboxConnectError(slug: "Kit!", bearer: "tok"))
    XCTAssertTrue(mailboxConnectError(slug: "kit", bearer: "")!.contains("Google session"))
    XCTAssertNil(mailboxConnectError(slug: "kit", bearer: "jwe"))
  }

  func testSocketHintCallsOutRoomListOnForbidden() {
    let hint = mailboxSocketHint(code: 403, detail: "forbidden")
    XCTAssertTrue(hint.contains("HTTP 403"))
    XCTAssertTrue(hint.contains("room list"))
  }

  func testSocketHintKeepsTransportDetailWhenThereIsNoHttp() {
    XCTAssertEqual(
      "Mailbox socket down — failed to connect",
      mailboxSocketHint(code: nil, detail: "failed to connect")
    )
  }

  func testSignedInWithNoCranesIsNotLive() {
    let hint = mailboxSignedInHint(email: "ada@example.com", cranes: [])
    XCTAssertTrue(hint.contains("ada@example.com"))
    XCTAssertTrue(hint.contains("no cranes"))
    XCTAssertEqual(
      "Signed in as ada@example.com",
      mailboxSignedInHint(email: "ada@example.com", cranes: ["kit"])
    )
  }

  func testAllowlistCopyIsEmailThenSub() {
    XCTAssertEqual("ada@example.com\n1182", allowlistCopy(email: "ada@example.com", sub: "1182"))
    XCTAssertEqual("1182", allowlistCopy(email: "  ", sub: "1182"))
    XCTAssertEqual("", allowlistCopy(email: "", sub: ""))
  }

  func testTimeoutHintIsASentence() {
    XCTAssertTrue(mailboxTimeoutHint().contains("timed out"))
  }

  func testRetryStopsOnAuthAndNotFound() {
    XCTAssertFalse(mailboxShouldRetry(401))
    XCTAssertFalse(mailboxShouldRetry(403))
    XCTAssertFalse(mailboxShouldRetry(404))
    XCTAssertFalse(mailboxShouldRetry(4401))
    XCTAssertTrue(mailboxShouldRetry(nil))
    XCTAssertTrue(mailboxShouldRetry(500))
  }

  func testSessionDropsOnHandshake401AndClose4401NotOn403() {
    XCTAssertTrue(mailboxHttpDropsSession(401))
    XCTAssertFalse(mailboxHttpDropsSession(403))
    XCTAssertFalse(mailboxHttpDropsSession(404))
    XCTAssertFalse(mailboxHttpDropsSession(nil))
    XCTAssertTrue(mailboxCloseDropsAuth(mailboxCloseUnauthorized))
    XCTAssertFalse(mailboxCloseDropsAuth(1000))
    XCTAssertFalse(mailboxCloseDropsAuth(1001))
    XCTAssertTrue(mailboxAuthLostHint().contains("sign in again"))
  }

  func testSweepOnlyWhileSomeoneWatchesAndNotBackToBack() {
    XCTAssertTrue(watchingThread(phoneResumed: true, carThreadVisible: false))
    XCTAssertTrue(watchingThread(phoneResumed: false, carThreadVisible: true))
    XCTAssertFalse(watchingThread(phoneResumed: false, carThreadVisible: false))
    XCTAssertTrue(sweepMinGapMs < sweepEveryMs)
  }

  func testRetryDelayDoublesThenCaps() {
    XCTAssertEqual(2_000, mailboxRetryDelayMs(0))
    XCTAssertEqual(4_000, mailboxRetryDelayMs(1))
    XCTAssertEqual(32_000, mailboxRetryDelayMs(4))
    XCTAssertEqual(60_000, mailboxRetryDelayMs(5))
    XCTAssertEqual(60_000, mailboxRetryDelayMs(99))
  }

  func testExpiredSessionIsAConnectError() {
    XCTAssertTrue(mailboxConnectError(slug: "kit", bearer: "", sessionExpired: true)!.contains("expired"))
    XCTAssertNil(mailboxConnectError(slug: "kit", bearer: "jwe", sessionExpired: false))
  }

  func testSessionExpZeroIsNotExpired() {
    XCTAssertFalse(sessionExpired(expEpochSec: 0, nowEpochSec: 9_999_999))
    XCTAssertFalse(sessionExpired(expEpochSec: 100, nowEpochSec: 99))
    XCTAssertTrue(sessionExpired(expEpochSec: 100, nowEpochSec: 100))
    XCTAssertTrue(sessionExpired(expEpochSec: 100, nowEpochSec: 101))
  }

  func testLiveBearerDoesNotFallBackToSpikeAfterGoogleExpires() {
    XCTAssertEqual("jwe", liveBearer(session: "jwe", sessionExp: 200, spike: "secret", nowEpochSec: 50))
    XCTAssertEqual("", liveBearer(session: "jwe", sessionExp: 100, spike: "secret", nowEpochSec: 100))
    XCTAssertEqual("secret", liveBearer(session: "", sessionExp: 100, spike: "secret", nowEpochSec: 200))
  }

  func testPersistSpikeOnlyOnLoopbackDebug() {
    XCTAssertTrue(persistSpikeAllowed(origin: "http://10.0.2.2:3000", hasGoogleSession: false, debugBuild: true))
    XCTAssertTrue(persistSpikeAllowed(origin: "http://localhost:3000", hasGoogleSession: false, debugBuild: true))
    XCTAssertTrue(persistSpikeAllowed(origin: "http://127.0.0.1:3000", hasGoogleSession: false, debugBuild: true))
    XCTAssertFalse(persistSpikeAllowed(origin: "https://pendant.example.com", hasGoogleSession: false, debugBuild: true))
    XCTAssertTrue(persistSpikeAllowed(origin: "https://pendant.example.com", hasGoogleSession: false, debugBuild: false))
    XCTAssertFalse(persistSpikeAllowed(origin: "http://10.0.2.2:3000", hasGoogleSession: true, debugBuild: true))
    XCTAssertFalse(loopbackMailboxHost(""))
  }
}
