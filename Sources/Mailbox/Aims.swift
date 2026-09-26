import Foundation
import CoreFoundation

/// Goals board (`kind: "aims"`). Crane only; the mailbox keeps the latest and
/// replays it on connect. Whole board every time; empty `aims` clears. Not a turn.
public let aimsMax = 5
public let aimDaysMax = 14
public let aimWeeksMax = 13
public let aimLinksMax = 3
public let aimSentenceMax = 200

private let aimNotes: Set<String> = ["nudged", "asked", "offered", "praised", "quiet", ""]

public struct AimDay: Equatable {
  public var day: String
  public var score: Int
  public var events: [Int64]

  public init(day: String, score: Int, events: [Int64]) {
    self.day = day
    self.score = score
    self.events = events
  }
}

public struct AimMetric: Equatable {
  public var metric: String
  public var mean: Double
  public var unit: String
  public var n: Int

  public init(metric: String, mean: Double, unit: String, n: Int) {
    self.metric = metric
    self.mean = mean
    self.unit = unit
    self.n = n
  }
}

public struct AimWeek: Equatable {
  public var start: String
  public var mean: Double
  public var up: Int
  public var against: Int
  public var metrics: [AimMetric]

  public init(start: String, mean: Double, up: Int, against: Int, metrics: [AimMetric]) {
    self.start = start
    self.mean = mean
    self.up = up
    self.against = against
    self.metrics = metrics
  }
}

public struct AimBlock: Equatable {
  public var days: Int
  public var up: Int
  public var against: Int
  public var mean: Double
  public var pct: Double

  public init(days: Int, up: Int, against: Int, mean: Double, pct: Double) {
    self.days = days
    self.up = up
    self.against = against
    self.mean = mean
    self.pct = pct
  }
}

public struct AimEffect: Equatable {
  public var a: String
  public var b: String
  public var metric: String
  public var r: Double
  public var n: Int

  public init(a: String, b: String, metric: String, r: Double, n: Int) {
    self.a = a
    self.b = b
    self.metric = metric
    self.r = r
    self.n = n
  }
}

public struct AimLink: Equatable {
  public var a: String
  public var b: String
  public var r: Double
  public var n: Int

  public init(a: String, b: String, r: Double, n: Int) {
    self.a = a
    self.b = b
    self.r = r
    self.n = n
  }
}

public struct Aim: Equatable {
  public var area: String
  public var sentence: String
  public var rating30: Double
  public var sum7: Int
  public var streak: Int
  public var note: String
  public var noteAt: String?
  public var days: [AimDay]
  public var weeks: [AimWeek]
  public var slope: Double?
  public var block: AimBlock?
  public var effect: AimEffect?

  public init(
    area: String,
    sentence: String,
    rating30: Double,
    sum7: Int,
    streak: Int,
    note: String,
    noteAt: String? = nil,
    days: [AimDay] = [],
    weeks: [AimWeek] = [],
    slope: Double? = nil,
    block: AimBlock? = nil,
    effect: AimEffect? = nil
  ) {
    self.area = area
    self.sentence = sentence
    self.rating30 = rating30
    self.sum7 = sum7
    self.streak = streak
    self.note = note
    self.noteAt = noteAt
    self.days = days
    self.weeks = weeks
    self.slope = slope
    self.block = block
    self.effect = effect
  }
}

public struct AimsBoard: Equatable {
  public var aims: [Aim]
  public var links: [AimLink]

  public init(aims: [Aim] = [], links: [AimLink] = []) {
    self.aims = aims
    self.links = links
  }

  public var isEmpty: Bool { aims.isEmpty }
}

/// Whole frame → board. Missing `aims` array is junk (`nil`); `[]` is a real clear.
public func parseAims(_ o: [String: Any]) -> AimsBoard? {
  guard let arr = JSON.array(o["aims"]) else {
    return nil
  }
  var aims: [Aim] = []
  for item in arr {
    if aims.count >= aimsMax {
      break
    }
    guard let row = JSON.dict(item), let aim = parseAim(row) else {
      continue
    }
    aims.append(aim)
  }
  let areas = Set(aims.map(\.area))
  return AimsBoard(aims: aims, links: parseLinks(JSON.array(o["links"]), areas: areas))
}

func parseAim(_ o: [String: Any]) -> Aim? {
  let area = jsonText(o, "area").trimmingCharacters(in: .whitespacesAndNewlines)
  if !aimAreaOk(area) {
    return nil
  }
  var sentence = jsonText(o, "sentence").trimmingCharacters(in: .whitespacesAndNewlines)
  if sentence.count > aimSentenceMax {
    sentence = String(sentence.prefix(aimSentenceMax))
  }
  if sentence.isEmpty {
    return nil
  }
  guard let rating30 = jsonFinite(o["rating30"]), rating30 >= -3, rating30 <= 3 else {
    return nil
  }
  guard let sum7 = jsonInt(o["sum7"]), let streak = jsonInt(o["streak"]) else {
    return nil
  }
  let note = jsonText(o, "note").trimmingCharacters(in: .whitespacesAndNewlines)
  if !aimNotes.contains(note) {
    return nil
  }
  guard let daysRaw = JSON.array(o["days"]) else {
    return nil
  }
  let noteAt = jsonText(o, "note_at")
  return Aim(
    area: area,
    sentence: sentence,
    rating30: rating30,
    sum7: sum7,
    streak: streak,
    note: note,
    noteAt: aimDayOk(noteAt) ? noteAt : nil,
    days: parseDays(daysRaw),
    weeks: parseWeeks(JSON.array(o["weeks"])),
    slope: jsonFinite(o["slope"]),
    block: parseBlock(JSON.dict(o["block"])),
    effect: parseEffect(JSON.dict(o["effect"]))
  )
}

private func parseDays(_ arr: [Any]) -> [AimDay] {
  var out: [AimDay] = []
  for item in arr {
    if out.count >= aimDaysMax {
      break
    }
    guard let d = JSON.dict(item) else {
      continue
    }
    let day = jsonText(d, "day")
    if !aimDayOk(day) {
      continue
    }
    guard let score = jsonInt(d["score"]) else {
      continue
    }
    out.append(AimDay(day: day, score: score, events: parseIds(JSON.array(d["events"]))))
  }
  return out
}

private func parseIds(_ arr: [Any]?) -> [Int64] {
  guard let arr else {
    return []
  }
  var out: [Int64] = []
  for item in arr {
    guard let n = jsonWholeNumber(item), n > 0 else {
      continue
    }
    out.append(n)
  }
  return out
}

private func parseWeeks(_ arr: [Any]?) -> [AimWeek] {
  guard let arr else {
    return []
  }
  var out: [AimWeek] = []
  for item in arr {
    if out.count >= aimWeeksMax {
      break
    }
    guard let w = JSON.dict(item) else {
      continue
    }
    let start = jsonText(w, "start")
    if !aimDayOk(start) {
      continue
    }
    guard let mean = jsonFinite(w["mean"]), let up = jsonInt(w["up"]), let against = jsonInt(w["against"]) else {
      continue
    }
    out.append(
      AimWeek(
        start: start,
        mean: mean,
        up: up,
        against: against,
        metrics: parseMetrics(JSON.array(w["metrics"]))
      )
    )
  }
  return out
}

private func parseMetrics(_ arr: [Any]?) -> [AimMetric] {
  guard let arr else {
    return []
  }
  var out: [AimMetric] = []
  for item in arr {
    guard let m = JSON.dict(item) else {
      continue
    }
    let metric = jsonText(m, "metric").trimmingCharacters(in: .whitespacesAndNewlines)
    if metric.isEmpty {
      continue
    }
    guard let mean = jsonFinite(m["mean"]), let n = jsonInt(m["n"]) else {
      continue
    }
    out.append(AimMetric(metric: metric, mean: mean, unit: jsonText(m, "unit").trimmingCharacters(in: .whitespaces), n: n))
  }
  return out
}

/// A half-formed block is dropped whole.
private func parseBlock(_ o: [String: Any]?) -> AimBlock? {
  guard let o else {
    return nil
  }
  guard let days = jsonInt(o["days"]), let up = jsonInt(o["up"]), let against = jsonInt(o["against"]) else {
    return nil
  }
  guard let mean = jsonFinite(o["mean"]), let pct = jsonFinite(o["pct"]), days > 0 else {
    return nil
  }
  return AimBlock(days: days, up: up, against: against, mean: mean, pct: pct)
}

private func parseEffect(_ o: [String: Any]?) -> AimEffect? {
  guard let o else {
    return nil
  }
  let metric = jsonText(o, "metric").trimmingCharacters(in: .whitespacesAndNewlines)
  if metric.isEmpty {
    return nil
  }
  guard let r = jsonFinite(o["r"]), let n = jsonInt(o["n"]) else {
    return nil
  }
  return AimEffect(
    a: jsonText(o, "a").trimmingCharacters(in: .whitespacesAndNewlines),
    b: jsonText(o, "b").trimmingCharacters(in: .whitespacesAndNewlines),
    metric: metric,
    r: r,
    n: n
  )
}

/// Cross-aim lines. Both ends must be areas on this board; `a == b` is dropped. Cap 3.
private func parseLinks(_ arr: [Any]?, areas: Set<String>) -> [AimLink] {
  guard let arr else {
    return []
  }
  var out: [AimLink] = []
  for item in arr {
    if out.count >= aimLinksMax {
      break
    }
    guard let l = JSON.dict(item) else {
      continue
    }
    let a = jsonText(l, "a").trimmingCharacters(in: .whitespacesAndNewlines)
    let b = jsonText(l, "b").trimmingCharacters(in: .whitespacesAndNewlines)
    if a == b || !areas.contains(a) || !areas.contains(b) {
      continue
    }
    guard let r = jsonFinite(l["r"]), let n = jsonInt(l["n"]) else {
      continue
    }
    out.append(AimLink(a: a, b: b, r: r, n: n))
  }
  return out
}

func aimAreaOk(_ s: String) -> Bool {
  if s.isEmpty || s.count > 48 {
    return false
  }
  return s.allSatisfy { ch in
    ch.isASCII && (ch.isNumber || ch == "_" || ch == "-" || (ch.isLetter && ch.isLowercase))
  }
}

func aimDayOk(_ s: String) -> Bool {
  let chars = Array(s)
  if chars.count != 10 {
    return false
  }
  for (i, ch) in chars.enumerated() {
    if i == 4 || i == 7 {
      if ch != "-" {
        return false
      }
    } else if !ch.isNumber {
      return false
    }
  }
  return true
}

private func jsonText(_ o: [String: Any], _ key: String) -> String {
  (o[key] as? String) ?? ""
}

private func jsonInt(_ raw: Any?) -> Int? {
  guard let n = jsonWholeNumber(raw), n >= Int64(Int.min), n <= Int64(Int.max) else {
    return nil
  }
  return Int(n)
}

func jsonFinite(_ raw: Any?) -> Double? {
  guard let raw, !(raw is NSNull) else {
    return nil
  }
  if let n = raw as? NSNumber {
    if CFGetTypeID(n) == CFBooleanGetTypeID() {
      return nil
    }
    let d = n.doubleValue
    return d.isFinite ? d : nil
  }
  if raw is Bool {
    return nil
  }
  if let d = raw as? Double {
    return d.isFinite ? d : nil
  }
  if let i = raw as? Int {
    return Double(i)
  }
  return nil
}

/// `+1.4` / `-0.4` / `0`.
public func signed(_ n: Double, decimals: Int = 1) -> String {
  if n == 0 {
    return "0"
  }
  let body = String(format: "%.\(decimals)f", locale: Locale(identifier: "en_US_POSIX"), n)
  return n > 0 ? "+" + body : body
}

public func signed(_ n: Int) -> String {
  n > 0 ? "+\(n)" : String(n)
}

/// `30d +1.4 · 7d +6 · streak 2 · asked`
public func statsLine(_ aim: Aim) -> String {
  var parts = ["30d \(signed(aim.rating30))", "7d \(signed(aim.sum7))", "streak \(aim.streak)"]
  if !aim.note.isEmpty {
    parts.append(aim.note)
  }
  return parts.joined(separator: " · ")
}

/// `slope +0.3/wk · block 4/10 (40%) · weight r -0.42 (n 9)`
public func trendLine(_ aim: Aim) -> String {
  var parts: [String] = []
  if let slope = aim.slope {
    parts.append("slope \(signed(slope))/wk")
  }
  if let block = aim.block {
    parts.append("block \(block.up)/\(block.days) (\(Int((block.pct * 100).rounded()))%)")
  }
  if let effect = aim.effect {
    parts.append("\(effect.metric) r \(signed(effect.r, decimals: 2)) (n \(effect.n))")
  }
  return parts.joined(separator: " · ")
}

/// `training → next-day weight r +0.38 (n 12)`
public func linkLine(_ link: AimLink) -> String {
  "\(link.a) → next-day \(link.b) r \(signed(link.r, decimals: 2)) (n \(link.n))"
}

public func goalsLabel(_ changed: Int) -> String {
  changed > 0 ? "goals (\(changed))" : "goals"
}

/// `|score|` 1…3 → 0.45…1.0 so a light day reads lighter than a strong one.
public func dayWeight(_ score: Int) -> Double {
  let n = min(3, max(0, abs(score)))
  if n == 0 {
    return 0.3
  }
  return 0.45 + 0.275 * Double(n - 1)
}

public func seenAims(_ board: AimsBoard) -> [String: String] {
  var out: [String: String] = [:]
  for aim in board.aims {
    out[aim.area] = aimRow(aim)
  }
  return out
}

/// New, changed, or gone since the last open. A never-seen board counts whole.
public func changedAims(_ board: AimsBoard, seen: [String: String]) -> Int {
  let now = seenAims(board)
  let differ = now.filter { seen[$0.key] != $0.value }.count
  let gone = seen.keys.filter { now[$0] == nil }.count
  return differ + gone
}

public func encodeSeenAims(_ seen: [String: String]) -> String {
  JSON.stringify(seen)
}

public func parseSeenAims(_ raw: String?) -> [String: String] {
  guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let o = JSON.object(raw) else {
    return [:]
  }
  var out: [String: String] = [:]
  for (key, value) in o {
    if aimAreaOk(key), let row = value as? String {
      out[key] = row
    }
  }
  return out
}

func aimRow(_ aim: Aim) -> String {
  let days = aim.days.map { "\($0.day):\($0.score):\($0.events.count)" }.joined(separator: ",")
  let weeks = aim.weeks.map { "\($0.start):\($0.mean):\($0.up):\($0.against)" }.joined(separator: ",")
  let slope = aim.slope.map { String($0) } ?? ""
  let block = aim.block.map { "\($0.days):\($0.up):\($0.against):\($0.mean):\($0.pct)" } ?? ""
  let effect = aim.effect.map { "\($0.metric):\($0.r):\($0.n)" } ?? ""
  return [
    aim.sentence, String(aim.rating30), String(aim.sum7), String(aim.streak), aim.note,
    aim.noteAt ?? "", days, weeks, slope, block, effect,
  ].joined(separator: "\u{1f}")
}

public func askAim(_ area: String) -> String {
  "/aims \(area)"
}

public let askAimsReport = "/aims"
public let askAimsRubric = "/aims rubric"
