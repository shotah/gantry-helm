import Foundation

public let threadCacheCharsMax = 4_000_000
public let threadCacheSettleMs: Int64 = 750
public let outboxMax = 50

/// Whose thread: mailbox origin, crane slug, and the signed-in human (email; empty on the spike).
public struct ThreadRoom: Equatable {
  public var origin: String
  public var slug: String
  public var user: String

  public init(origin: String, slug: String, user: String) {
    self.origin = origin
    self.slug = slug
    self.user = user
  }
}

/**
 Settled bubbles only, like pendant `persistableThread`: a `sending` bubble
 either lands (the transcript replays it) or never did; a draft is Kit
 mid-sentence. Neither should greet you as history. `live` is a this-session
 SwiftUI id — a reload must not keep it.
 */
public func persistableThread(_ lines: [ChatLine]) -> [ChatLine] {
  lines.filter { !$0.pending && !isDraftBubble($0.kind) }
    .map { line in
      var line = line
      if line.live {
        line.live = false
      }
      return line
    }
}

public final class ThreadCache {
  private let file: URL

  public init(file: URL) {
    self.file = file
  }

  public func read(_ room: ThreadRoom) -> [ChatLine] {
    guard let raw = try? String(contentsOf: file, encoding: .utf8) else {
      return []
    }
    return decodeThread(raw, room: room)
  }

  public func write(_ room: ThreadRoom, lines: [ChatLine]) {
    do {
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let tmp = file.appendingPathExtension("tmp")
      try encodeThread(room, lines: lines).write(to: tmp, atomically: true, encoding: .utf8)
      _ = try? FileManager.default.removeItem(at: file)
      try FileManager.default.moveItem(at: tmp, to: file)
    } catch {
      /* a cache that cannot write is still a cache */
    }
  }
}

public func encodeThread(
  _ room: ThreadRoom,
  lines: [ChatLine],
  maxChars: Int = threadCacheCharsMax
) -> String {
  var kept: [[String: Any]] = []
  var used = 0
  for line in persistableThread(lines).reversed() {
    let o = encodeLine(line)
    let n = JSON.stringify(o).count
    used += n
    if used > maxChars {
      break
    }
    kept.append(o)
  }
  let obj: [String: Any] = [
    "origin": room.origin,
    "slug": room.slug,
    "user": room.user,
    "lines": kept.reversed(),
  ]
  return JSON.stringify(obj)
}

public func decodeThread(_ raw: String, room: ThreadRoom) -> [ChatLine] {
  guard let o = JSON.object(raw) else {
    return []
  }
  let got = ThreadRoom(
    origin: (o["origin"] as? String) ?? "",
    slug: (o["slug"] as? String) ?? "",
    user: (o["user"] as? String) ?? ""
  )
  if got != room {
    return []
  }
  guard let arr = o["lines"] as? [Any] else {
    return []
  }
  var out: [ChatLine] = []
  for item in arr {
    guard let obj = item as? [String: Any], let line = decodeLine(obj) else {
      continue
    }
    out.append(line)
  }
  return capThread(out, max: threadMax)
}

private func encodeLine(_ line: ChatLine) -> [String: Any] {
  var o: [String: Any] = [
    "id": line.id,
    "you": line.fromYou,
    "text": line.text,
    "at": line.at,
  ]
  if let kind = line.kind {
    o["kind"] = kind
  }
  if let photo = line.photo {
    o["photo"] = photo
  }
  if let seq = line.seq {
    o["seq"] = seq
  }
  if let failed = line.failed {
    o["failed"] = failed
  }
  return o
}

private func decodeLine(_ o: [String: Any]) -> ChatLine? {
  let id = (o["id"] as? String) ?? ""
  if id.isEmpty {
    return nil
  }
  let kindRaw = (o["kind"] as? String) ?? ""
  let kind: String? = kindRaw.isEmpty ? nil : kindRaw
  if isDraftBubble(kind) {
    return nil
  }
  let seq: Int?
  if JSON.isNull(o, "seq") || o["seq"] == nil {
    seq = nil
  } else {
    seq = orderSeq(o["seq"])
  }
  let photo = o["photo"] as? String
  return ChatLine(
    id: id,
    fromYou: JSON.bool(o, "you"),
    text: (o["text"] as? String) ?? "",
    kind: kind,
    photo: photo.flatMap { cachedPhotoOk($0) ? $0 : nil },
    at: jsonWholeNumber(o["at"]) ?? 0,
    seq: seq,
    failed: {
      let f = (o["failed"] as? String) ?? ""
      return f.isEmpty ? nil : f
    }()
  )
}

/// Same shapes the wire admits; anything else on disk is not a photo.
private func cachedPhotoOk(_ url: String) -> Bool {
  url.hasPrefix("data:image/") || url.hasPrefix("https://")
}

/// Queue of inbound frames while the socket is down. Cap matches Cab (50).
public struct Outbox {
  public var frames: [WireFrame] = []

  public init(frames: [WireFrame] = []) {
    self.frames = frames
  }

  @discardableResult
  public mutating func push(_ frame: WireFrame) -> Bool {
    if frames.count >= outboxMax {
      return false
    }
    frames.append(frame)
    return true
  }

  public mutating func popAll() -> [WireFrame] {
    let all = frames
    frames = []
    return all
  }
}

/// Catch-up cursor the socket holds. Frames already seen restamp by id.
public final class SeenCursor {
  public private(set) var lastSeenId: String?
  public private(set) var lastSeenSeq: Int = 0
  private var seen: [String] = []

  public init() {}

  public func remember(id: String, seq: Int? = nil) {
    let next = advanceCursor(ThreadCursor(id: lastSeenId, seq: lastSeenSeq), id: id, seq: seq)
    lastSeenId = next.id
    lastSeenSeq = next.seq
    rememberSeen(&seen, id: id)
  }

  public func since() -> String? {
    ackSince(ThreadCursor(id: lastSeenId, seq: lastSeenSeq))
  }

  public func note(frame: WireFrame) {
    guard let id = frame.id, movesCursor(frame.kind) else {
      return
    }
    remember(id: id, seq: frame.seq)
  }
}
