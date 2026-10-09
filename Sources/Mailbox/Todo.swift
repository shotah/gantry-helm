import Foundation

/// Tasks board (`kind: "todo"`). Crane only; the mailbox keeps the latest and
/// replays it on connect. Whole list every time, oldest first; empty clears.
/// Not a turn. The one write the phone makes is the checkbox, and it is an
/// ordinary visible turn: `/todo done <id>`. Same shape and caps as pendant
/// `lib/mailbox/todo.ts`.
public let todoMax = 100

/// Runes (Unicode scalars), pendant `TODO_TEXT_MAX`.
public let todoTextMax = 240

/// Past this many open the footer says it is a pocket list, not a tracker.
public let todoPocketMax = 10

public let todoListCommand = "/todo"

public struct TodoRow: Equatable, Identifiable {
  /// Memory row id; what the checkbox sends back. Changes when the words change.
  public var id: Int64
  /// Key after `todo/`; the identity across rewrites.
  public var slug: String
  public var text: String
  /// Local `YYYY-MM-DD` last written. The phone computes the age.
  public var at: String

  public init(id: Int64, slug: String, text: String, at: String) {
    self.id = id
    self.slug = slug
    self.text = text
    self.at = at
  }
}

/// Whole frame → rows. Missing `todo` array is junk (`nil`); `[]` is a real clear.
public func parseTodo(_ o: [String: Any]) -> [TodoRow]? {
  guard let arr = JSON.array(o["todo"]) else {
    return nil
  }
  var ids = Set<Int64>()
  var slugs = Set<String>()
  var rows: [TodoRow] = []
  for item in arr {
    if rows.count >= todoMax {
      break
    }
    guard let raw = JSON.dict(item), let row = parseTodoRow(raw) else {
      continue
    }
    if !ids.insert(row.id).inserted || !slugs.insert(row.slug).inserted {
      continue
    }
    rows.append(row)
  }
  return rows
}

private func parseTodoRow(_ o: [String: Any]) -> TodoRow? {
  guard let id = jsonWholeNumber(o["id"]), id > 0 else {
    return nil
  }
  let slug = (JSON.string(o, "slug") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  guard slugOk(slug) else {
    return nil
  }
  let text = collapseWhitespace(JSON.string(o, "text") ?? "")
  guard !text.isEmpty else {
    return nil
  }
  let at = (JSON.string(o, "at") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  guard dateShape(at) else {
    return nil
  }
  return TodoRow(id: id, slug: slug, text: capRunes(text, todoTextMax), at: at)
}

private func slugOk(_ s: String) -> Bool {
  s.range(of: "^[a-z0-9][a-z0-9_-]*$", options: .regularExpression) != nil
}

private func dateShape(_ s: String) -> Bool {
  s.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil
}

private func collapseWhitespace(_ s: String) -> String {
  s.split { $0.isWhitespace }.map(String.init).joined(separator: " ")
}

private func capRunes(_ s: String, _ max: Int) -> String {
  let scalars = s.unicodeScalars
  if scalars.count <= max {
    return s
  }
  let end = scalars.index(scalars.startIndex, offsetBy: max)
  return String(String.UnicodeScalarView(scalars[..<end]))
}

/// Whole days since `at`; nil when `at` does not parse or is in the future.
public func todoAgeDays(_ at: String, today: String) -> Int? {
  guard let from = civilDay(at), let to = civilDay(today) else {
    return nil
  }
  var cal = Calendar(identifier: .gregorian)
  cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
  let days = cal.dateComponents([.day], from: from, to: to).day
  guard let days, days >= 0 else {
    return nil
  }
  return days
}

/// `3d ago` after the first day; nothing on the day it was written.
public func ageLabel(_ at: String, today: String) -> String? {
  guard let days = todoAgeDays(at, today: today), days >= 1 else {
    return nil
  }
  return "\(days)d ago"
}

/// `#412 · dentist · 3d ago` — id, slug, age after the first day.
public func todoMeta(_ row: TodoRow, today: String) -> String {
  var parts = ["#\(row.id)", row.slug]
  if let age = ageLabel(row.at, today: today) {
    parts.append(age)
  }
  return parts.joined(separator: " · ")
}

/// The checkbox: the one kernel write, as a visible turn.
public func todoDoneCommand(_ id: Int64) -> String {
  "/todo done \(id)"
}

/// Adding is plain words to Kit, who names the row. Nil when there are no words.
public func todoAddText(_ words: String) -> String? {
  let w = collapseWhitespace(words)
  return w.isEmpty ? nil : "add to my list: \(w)"
}

/// The `/todo` footer's words past ten open; nil under.
public func pocketFooter(_ open: Int) -> String? {
  open > todoPocketMax ? "\(open) open — a pocket list; prune, or use a tracker" : nil
}

/// Header chip text; the number is tasks that changed since the last open.
public func tasksLabel(_ changed: Int) -> String {
  changed > 0 ? "tasks (\(changed))" : "tasks"
}

/// Keyed by slug: a rewrite changes the id, not the task.
public func seenTodo(_ rows: [TodoRow]) -> [String: String] {
  var out: [String: String] = [:]
  for row in rows {
    out[row.slug] = todoRowJson(row)
  }
  return out
}

public func changedTodo(_ rows: [TodoRow], seen: [String: String]) -> Int {
  let now = seenTodo(rows)
  let differ = now.filter { seen[$0.key] != $0.value }.count
  let gone = seen.keys.filter { now[$0] == nil }.count
  return differ + gone
}

public func encodeSeenTodo(_ seen: [String: String]) -> String {
  JSON.stringify(seen)
}

public func parseSeenTodo(_ raw: String?) -> [String: String] {
  guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
    let o = JSON.object(raw)
  else {
    return [:]
  }
  var out: [String: String] = [:]
  for (key, value) in o {
    if slugOk(key), let row = value as? String {
      out[key] = row
    }
  }
  return out
}

private func todoRowJson(_ row: TodoRow) -> String {
  let arr: [Any] = [NSNumber(value: row.id), row.text, row.at]
  guard JSONSerialization.isValidJSONObject(arr),
    let data = try? JSONSerialization.data(withJSONObject: arr),
    let s = String(data: data, encoding: .utf8)
  else {
    return "[]"
  }
  return s
}

/// No wire change: the crane leads `text` with `!! ` (urgent) or `! ` (high).
/// `text` stays raw — the seen badge keys on it — so these read it, not rewrite it.
public enum TodoPriority: Int, Equatable, CaseIterable {
  case urgent
  case high
  case normal
}

private let urgentMarker = "!! "
private let highMarker = "! "

/// `!!!`, a glued `!!file`, or a bare `!!` are words, not a marker.
public func todoPriority(_ text: String) -> TodoPriority {
  if leadsWith(text, urgentMarker) {
    return .urgent
  }
  if leadsWith(text, highMarker) {
    return .high
  }
  return .normal
}

/// The words after the marker; the whole text when there is none.
public func todoWords(_ text: String) -> String {
  switch todoPriority(text) {
  case .urgent: return String(text.dropFirst(urgentMarker.count))
  case .high: return String(text.dropFirst(highMarker.count))
  case .normal: return text
  }
}

/// The coloured tag ahead of the words; nil for normal.
public func todoTag(_ priority: TodoPriority) -> String? {
  switch priority {
  case .urgent: return "!!"
  case .high: return "!"
  case .normal: return nil
  }
}

/// Accessibility label for the tag; nil for normal.
public func todoPriorityLabel(_ priority: TodoPriority) -> String? {
  switch priority {
  case .urgent: return "urgent"
  case .high: return "high"
  case .normal: return nil
  }
}

/// Urgent → high → rest; oldest first (the wire order) inside each rank.
public func sortTodo(_ rows: [TodoRow]) -> [TodoRow] {
  TodoPriority.allCases.flatMap { rank in rows.filter { todoPriority($0.text) == rank } }
}

private func leadsWith(_ text: String, _ marker: String) -> Bool {
  guard text.hasPrefix(marker) else {
    return false
  }
  return !text.dropFirst(marker.count).trimmingCharacters(in: .whitespaces).isEmpty
}

/// A tick is local until the next `todo` frame settles it.
public func settleTicked() -> Set<Int64> {
  []
}

/// Tap once; a second tap on a ticked row must not send `/todo done` again.
public func canTick(id: Int64, ticked: Set<Int64>) -> Bool {
  !ticked.contains(id)
}

private func civilDay(_ ymd: String) -> Date? {
  guard dateShape(ymd) else {
    return nil
  }
  let parts = ymd.split(separator: "-")
  guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
  else {
    return nil
  }
  var cal = Calendar(identifier: .gregorian)
  cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
  var c = DateComponents()
  c.year = y
  c.month = m
  c.day = d
  guard let date = cal.date(from: c) else {
    return nil
  }
  let back = cal.dateComponents([.year, .month, .day], from: date)
  guard back.year == y, back.month == m, back.day == d else {
    return nil
  }
  return date
}
