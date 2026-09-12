/// Mailbox order on a thread bubble. Seq first, then `at`, then id.
public protocol ThreadOrder {
  var id: String { get }
  var at: Int64 { get }
  var seq: Int? { get }
  var kind: String? { get }
}

public struct ThreadCursor: Equatable {
  public var id: String?
  public var seq: Int

  public init(id: String? = nil, seq: Int = 0) {
    self.id = id
    self.seq = seq
  }
}

public let threadMax = 80
public let seenMax = 200

public func capThread<T>(_ messages: [T], max: Int = threadMax) -> [T] {
  if messages.count > max {
    return Array(messages.suffix(max))
  }
  return messages
}

public func isDraftBubble(_ kind: String?) -> Bool {
  kind == "draft"
}

/// Seq first, then mailbox time, then id. Drafts stay last so catch-up cannot leapfrog typing.
public func compareThread(_ a: ThreadOrder, _ b: ThreadOrder) -> Bool {
  // true if a should come before b
  let aDraft = isDraftBubble(a.kind)
  let bDraft = isDraftBubble(b.kind)
  if aDraft != bDraft {
    return !aDraft
  }
  if let aSeq = a.seq, let bSeq = b.seq, aSeq != bSeq {
    return aSeq < bSeq
  }
  if a.at != b.at {
    return a.at < b.at
  }
  return a.id < b.id
}

public func placeInThread<T: ThreadOrder>(_ messages: [T], _ bubble: T) -> [T] {
  let next = messages.filter { $0.id != bubble.id } + [bubble]
  return next.sorted { compareThread($0, $1) }
}

public func advanceCursor(_ current: ThreadCursor, id: String? = nil, seq: Int? = nil) -> ThreadCursor {
  if let seq, seq >= current.seq {
    return ThreadCursor(id: id ?? current.id, seq: seq)
  }
  if seq == nil, let id {
    return ThreadCursor(id: id, seq: current.seq)
  }
  return current
}

/**
 Only queued turns advance `since`. An `ack` echoes our own id; an `error`
 names the frame the mailbox refused — neither is a place to resume from.
 */
public func movesCursor(_ kind: String?) -> Bool {
  kind != "ack" && kind != "error" && kind != "face" && kind != "backdrop" && kind != "theme"
}

/**
 Highest mailbox `seq` on a thread already on the device, for the first
 `ack` `since` of a fresh socket. Bubbles the mailbox never stamped (refused
 or still sending) do not count. Pendant `cursorOf`.
 */
public func cursorOf(_ lines: [some ThreadOrder]) -> ThreadCursor {
  lines.reduce(ThreadCursor()) { cur, line in
    guard let seq = line.seq else {
      return cur
    }
    return advanceCursor(cur, id: line.id, seq: seq)
  }
}

public func ackSince(_ cursor: ThreadCursor) -> String? {
  if cursor.seq > 0 {
    return String(cursor.seq)
  }
  return cursor.id
}

public func rememberSeen(_ seen: inout [String], id: String, max: Int = seenMax) {
  if !seen.contains(id) {
    seen.append(id)
  }
  if seen.count > max {
    seen.removeFirst(seen.count - max)
  }
}
