import XCTest

@testable import Mailbox

/// The pendant `docs/frontends.md` Tasks board sample.
private let list = """
  {
    "kind": "todo",
    "todo": [
      { "id": 412, "slug": "dentist",  "text": "call to book a cleaning", "at": "2026-09-23" },
      { "id": 418, "slug": "passport", "text": "renew, by Oct 15",        "at": "2026-09-26" }
    ]
  }
  """

final class TodoTests: XCTestCase {
  private let today = "2026-09-26"

  func testParsesTheFrontendsSampleOldestFirst() {
    let rows = parseTodo(JSON.object(list)!)!
    XCTAssertEqual([412, 418], rows.map(\.id))
    XCTAssertEqual(["dentist", "passport"], rows.map(\.slug))
    XCTAssertEqual("call to book a cleaning", rows[0].text)
    XCTAssertEqual("2026-09-23", rows[0].at)
  }

  func testEmptyIsAClearAndAMissingArrayIsJunk() {
    XCTAssertEqual([], parseTodo(JSON.object(#"{"kind":"todo","todo":[]}"#)!)!)
    XCTAssertNil(parseTodo(JSON.object(#"{"kind":"todo"}"#)!))
    XCTAssertNil(parseTodo(JSON.object(#"{"kind":"todo","todo":"nope"}"#)!))
  }

  func testDropsABadRowNotTheListAndARepeatOfEitherKey() {
    let raw = """
      {"todo":[
        {"id":0,"slug":"zero","text":"no","at":"2026-09-01"},
        {"id":1,"slug":"Bad","text":"no","at":"2026-09-01"},
        {"id":2,"slug":"blank","text":"   ","at":"2026-09-01"},
        {"id":3,"slug":"nodate","text":"x","at":"yesterday"},
        {"id":4,"slug":"ok","text":"  call   them  ","at":"2026-09-01"},
        {"id":4,"slug":"again","text":"same id","at":"2026-09-02"},
        {"id":5,"slug":"ok","text":"same slug","at":"2026-09-02"}
      ]}
      """
    let rows = parseTodo(JSON.object(raw)!)!
    XCTAssertEqual([4], rows.map(\.id))
    XCTAssertEqual("call them", rows[0].text)
  }

  func testKeepsAHundredAndDropsTheRest() {
    let rows = (1...120).map { i in
      #"{"id":\#(i),"slug":"t\#(i)","text":"do \#(i)","at":"2026-09-01"}"#
    }.joined(separator: ",")
    let parsed = parseTodo(JSON.object(#"{"todo":[\#(rows)]}"#)!)!
    XCTAssertEqual(todoMax, parsed.count)
    XCTAssertEqual(1, parsed.first?.id)
    XCTAssertEqual(100, parsed.last?.id)
  }

  func testTextCollapsesAndCapsAt240Runes() {
    let long = String(repeating: "あ", count: todoTextMax + 5)
    let raw = #"{"todo":[{"id":1,"slug":"x","text":"\#(long)","at":"2026-09-01"}]}"#
    let rows = parseTodo(JSON.object(raw)!)!
    XCTAssertEqual(todoTextMax, rows[0].text.unicodeScalars.count)
  }

  func testAgeShowsAfterTheFirstDay() {
    let old = TodoRow(id: 412, slug: "dentist", text: "call", at: "2026-09-23")
    let fresh = TodoRow(id: 418, slug: "passport", text: "renew", at: "2026-09-26")
    XCTAssertEqual("#412 · dentist · 3d ago", todoMeta(old, today: today))
    XCTAssertEqual("#418 · passport", todoMeta(fresh, today: today))
    XCTAssertNil(ageLabel("not-a-day", today: today))
    XCTAssertNil(ageLabel("2026-09-27", today: today))
    XCTAssertNil(ageLabel("2026-02-31", today: today))
  }

  func testTheCheckboxIsOneCommandAndAddIsPlainWords() {
    XCTAssertEqual("/todo done 412", todoDoneCommand(412))
    XCTAssertEqual("add to my list: book a cleaning", todoAddText("  book   a cleaning "))
    XCTAssertNil(todoAddText("   "))
    XCTAssertEqual("/todo", todoListCommand)
    XCTAssertTrue(canTick(id: 412, ticked: []))
    XCTAssertFalse(canTick(id: 412, ticked: [412]))
    XCTAssertTrue(settleTicked().isEmpty)
  }

  func testFooterOnlyPastTen() {
    XCTAssertNil(pocketFooter(10))
    XCTAssertEqual("11 open — a pocket list; prune, or use a tracker", pocketFooter(11))
    XCTAssertEqual("tasks", tasksLabel(0))
    XCTAssertEqual("tasks (2)", tasksLabel(2))
  }

  func testBadgeKeysOnSlugSoARewriteIsOneChange() {
    let rows = parseTodo(JSON.object(list)!)!
    XCTAssertEqual(2, changedTodo(rows, seen: [:]))
    let seen = seenTodo(rows)
    XCTAssertEqual(0, changedTodo(rows, seen: seen))
    let rewritten = rows.map { row in
      row.slug == "dentist" ? TodoRow(id: 500, slug: row.slug, text: row.text, at: row.at) : row
    }
    XCTAssertEqual(1, changedTodo(rewritten, seen: seen))
    XCTAssertEqual(1, changedTodo(rows.filter { $0.slug == "passport" }, seen: seen))
    XCTAssertEqual(seen, parseSeenTodo(encodeSeenTodo(seen)))
    XCTAssertTrue(parseSeenTodo("nope").isEmpty)
  }

  func testRideOnTheWireOnlyAsATodoKind() {
    let frame = parseFrame(list)!
    XCTAssertEqual("todo", frame.kind)
    XCTAssertEqual(2, frame.todo?.count)
    XCTAssertNil(frame.text)
    XCTAssertNil(parseFrame(#"{"kind":"push","text":"hi","todo":[]}"#)!.todo)
    XCTAssertFalse(movesCursor("todo"))
  }

  func testPriorityLeadsTheTextAndGluedOrTripleBangsAreWords() {
    XCTAssertEqual(.urgent, todoPriority("!! call the vet"))
    XCTAssertEqual(.high, todoPriority("! renew passport"))
    XCTAssertEqual(.normal, todoPriority("buy milk"))
    XCTAssertEqual(.normal, todoPriority("!!! loud"))
    XCTAssertEqual(.normal, todoPriority("!!file"))
    XCTAssertEqual(.normal, todoPriority("!!"))
    XCTAssertEqual(.normal, todoPriority("!"))
    XCTAssertEqual(.normal, todoPriority("!! "))
    XCTAssertEqual("call the vet", todoWords("!! call the vet"))
    XCTAssertEqual("renew passport", todoWords("! renew passport"))
    XCTAssertEqual("!!! loud", todoWords("!!! loud"))
    XCTAssertEqual("!!file", todoWords("!!file"))
    XCTAssertEqual("!!", todoTag(.urgent))
    XCTAssertEqual("!", todoTag(.high))
    XCTAssertNil(todoTag(.normal))
    XCTAssertEqual("urgent", todoPriorityLabel(.urgent))
    XCTAssertEqual("high", todoPriorityLabel(.high))
    XCTAssertNil(todoPriorityLabel(.normal))
  }

  func testSortIsUrgentThenHighThenRestOldestFirstInsideEachRank() {
    let rows = [
      TodoRow(id: 1, slug: "a", text: "plain one", at: "2026-09-01"),
      TodoRow(id: 2, slug: "b", text: "! high one", at: "2026-09-02"),
      TodoRow(id: 3, slug: "c", text: "!! urgent one", at: "2026-09-03"),
      TodoRow(id: 4, slug: "d", text: "plain two", at: "2026-09-04"),
      TodoRow(id: 5, slug: "e", text: "!! urgent two", at: "2026-09-05"),
      TodoRow(id: 6, slug: "f", text: "! high two", at: "2026-09-06"),
    ]
    XCTAssertEqual([3, 5, 2, 6, 1, 4], sortTodo(rows).map(\.id))
    XCTAssertEqual([], sortTodo([]))
    // The raw text is what the seen badge keys on; the marker stays in it.
    XCTAssertEqual(0, changedTodo(sortTodo(rows), seen: seenTodo(rows)))
  }

  func testIngestReplacesTheListAndNeverPaintsABubble() {
    let mouth = Mouth()
    XCTAssertFalse(mouth.ingest(parseFrame(list)!))
    XCTAssertEqual(2, mouth.todo.count)
    XCTAssertTrue(mouth.lines.isEmpty)
    mouth.ingest(parseFrame(#"{"kind":"todo","text":"nope"}"#)!)
    XCTAssertEqual(2, mouth.todo.count)
    XCTAssertTrue(mouth.lines.isEmpty)
    mouth.ingest(parseFrame(#"{"kind":"todo","todo":[]}"#)!)
    XCTAssertTrue(mouth.todo.isEmpty)
    mouth.ingest(parseFrame(list)!)
    mouth.replace(lines: [], up: false, hint: "")
    XCTAssertTrue(mouth.todo.isEmpty)
  }
}
