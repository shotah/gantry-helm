import XCTest
@testable import Mailbox

final class ThreadCacheTests: XCTestCase {
  let room = ThreadRoom(origin: "https://mailbox.example", slug: "kit", user: "ada@example.com")

  private func thread() -> [ChatLine] {
    [
      ChatLine(id: "a0", fromYou: true, text: "still sending", kind: "inbound", pending: true, at: 5),
      ChatLine(id: "a1", fromYou: true, text: "hatch?", kind: "inbound", at: 10, seq: 1),
      ChatLine(id: "k1", fromYou: false, text: "latched", kind: "reply", at: 20, seq: 2),
      ChatLine(id: "p1", fromYou: false, text: "", kind: "push", photo: "data:image/jpeg;base64,aa", at: 30, seq: 3),
      ChatLine(id: "a2", fromYou: true, text: "nope", kind: "inbound", at: 40, failed: "Not sent — too big for the room."),
      ChatLine(id: draftId, fromYou: false, text: "Gate's on…", kind: "draft", at: 50),
    ]
  }

  private func settled() -> [ChatLine] {
    Array(thread().dropFirst().dropLast())
  }

  func testWriteThenReadRoundTripsSettledBubblesOnly() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = dir.appendingPathComponent("recall/thread.json")
    let cache = ThreadCache(file: file)
    XCTAssertEqual([], cache.read(room))
    cache.write(room, lines: thread())
    let back = cache.read(room)
    XCTAssertEqual(settled(), back)
    XCTAssertEqual(1, back[0].seq)
    XCTAssertNil(back[3].seq)
    XCTAssertEqual("Not sent — too big for the room.", back[3].failed)
    XCTAssertFalse(back.contains { $0.pending })
    XCTAssertFalse(FileManager.default.fileExists(atPath: file.appendingPathExtension("tmp").path))
  }

  func testPersistableThreadDropsSendingAndDrafts() {
    XCTAssertEqual(["a1", "k1", "p1", "a2"], persistableThread(thread()).map(\.id))
  }

  func testPersistableThreadStripsLive() {
    let live = ChatLine(id: "r1", fromYou: false, text: "Hello", kind: "reply", live: true)
    let kept = persistableThread([live])[0]
    XCTAssertEqual("r1", kept.id)
    XCTAssertEqual(false, kept.live)
  }

  func testAnotherRoomOriginOrHumanReadsBackEmpty() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let cache = ThreadCache(file: dir.appendingPathComponent("thread.json"))
    cache.write(room, lines: thread())
    XCTAssertEqual([], cache.read(ThreadRoom(origin: room.origin, slug: "ada", user: room.user)))
    XCTAssertEqual([], cache.read(ThreadRoom(origin: "https://other.example", slug: room.slug, user: room.user)))
    XCTAssertEqual([], cache.read(ThreadRoom(origin: room.origin, slug: room.slug, user: "bob@example.com")))
    XCTAssertEqual([], cache.read(ThreadRoom(origin: room.origin, slug: room.slug, user: "")))
    XCTAssertEqual(4, cache.read(room).count)
  }

  func testJunkOnDiskIsAnEmptyThread() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("thread.json")
    try "{nope".write(to: file, atomically: true, encoding: .utf8)
    XCTAssertEqual([], ThreadCache(file: file).read(room))
    let raw =
      #"{"origin":"\#(room.origin)","slug":"kit","user":"\#(room.user)","lines":[{"text":"no id"},7,{"id":"ok","text":"hi"}]}"#
    try raw.write(to: file, atomically: true, encoding: .utf8)
    XCTAssertEqual([ChatLine(id: "ok", fromYou: false, text: "hi", kind: nil)], ThreadCache(file: file).read(room))
  }

  func testUnwritablePathIsQuiet() {
    let blocked = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? "x".write(to: blocked, atomically: true, encoding: .utf8)
    let cache = ThreadCache(file: blocked.appendingPathComponent("thread.json"))
    cache.write(room, lines: thread())
    XCTAssertEqual([], cache.read(room))
  }

  func testCapKeepsTheNewestLinesAndOneMaxPhotoFits() {
    let big = (0..<6).map { ChatLine(id: "b\($0)", fromYou: false, text: String(repeating: "x", count: 100), kind: "reply", at: Int64($0)) }
    let raw = encodeThread(room, lines: big, maxChars: 400)
    XCTAssertEqual(["b4", "b5"], decodeThread(raw, room: room).map(\.id))
    XCTAssertEqual([], decodeThread(encodeThread(room, lines: big, maxChars: 1), room: room))
    let photo = ChatLine(
      id: "ph", fromYou: true, text: "", kind: "inbound",
      photo: "data:image/jpeg;base64," + String(repeating: "a", count: 2_000_000)
    )
    XCTAssertEqual(["ph"], decodeThread(encodeThread(room, lines: [photo]), room: room).map(\.id))
  }

  func testOnlyWirePhotoShapesComeBack() {
    let lines = [
      ChatLine(id: "f", fromYou: true, text: "", kind: "inbound", photo: "file:///etc/passwd"),
      ChatLine(id: "h", fromYou: true, text: "", kind: "inbound", photo: "https://img.example/a.jpg"),
    ]
    let back = decodeThread(encodeThread(room, lines: lines), room: room)
    XCTAssertNil(back[0].photo)
    XCTAssertEqual("https://img.example/a.jpg", back[1].photo)
  }

  func testDecodeCapsAtTheThreadMaxAndDropsNonPositiveSeq() {
    let many = (0..<100).map { ChatLine(id: "m\($0)", fromYou: false, text: "n\($0)", kind: "reply", at: Int64($0)) }
    let back = decodeThread(encodeThread(room, lines: many), room: room)
    XCTAssertEqual(80, back.count)
    XCTAssertEqual("m20", back.first?.id)
    let raw = encodeThread(room, lines: [ChatLine(id: "z", fromYou: false, text: "z", kind: "reply", seq: 0)])
    XCTAssertNil(decodeThread(raw, room: room)[0].seq)
  }

  func testSeenCursorAcksHighestSeq() {
    let seen = SeenCursor()
    seen.remember(id: "b", seq: 2)
    seen.remember(id: "a", seq: 1)
    XCTAssertEqual("2", seen.since())
    seen.note(frame: WireFrame(kind: "ack", id: "x", seq: 9))
    XCTAssertEqual("2", seen.since())
    seen.note(frame: WireFrame(kind: "reply", id: "c", seq: 9))
    XCTAssertEqual("9", seen.since())
  }

  func testOutboxCapsAtFifty() {
    var box = Outbox()
    for i in 0..<outboxMax {
      XCTAssertTrue(box.push(inbound("n\(i)", id: "\(i)", context: nil)))
    }
    XCTAssertFalse(box.push(inbound("nope", id: "overflow", context: nil)))
    XCTAssertEqual(outboxMax, box.frames.count)
    XCTAssertEqual(outboxMax, box.popAll().count)
    XCTAssertEqual([], box.frames)
  }
}
