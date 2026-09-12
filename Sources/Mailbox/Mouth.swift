import Foundation

public let draftId = "__draft__"

/// This-session SwiftUI id so draft→reply does not remount markdown.
public let liveComposeKey = "kit-live"

/// Phone TTL after the last typing frame. Crane refresh is ~4s.
public let typingTtlMs: Int64 = 6_000

public func composeKey(_ line: ChatLine) -> String {
  line.live ? liveComposeKey : line.id
}

public func clearsTyping(_ kind: String?) -> Bool {
  kind == "reply" || kind == "push" || kind == "error"
}

public struct ChatLine: Equatable, ThreadOrder {
  public var id: String
  public var fromYou: Bool
  public var text: String
  public var kind: String?
  public var photo: String?
  public var pending: Bool
  public var at: Int64
  public var seq: Int?
  /// Mailbox refused it; sentence from `describeSendError`.
  public var failed: String?
  /// This-session SwiftUI id; never persist (pendant `live`).
  public var live: Bool

  public init(
    id: String,
    fromYou: Bool,
    text: String,
    kind: String?,
    photo: String? = nil,
    pending: Bool = false,
    at: Int64 = 0,
    seq: Int? = nil,
    failed: String? = nil,
    live: Bool = false
  ) {
    self.id = id
    self.fromYou = fromYou
    self.text = text
    self.kind = kind
    self.photo = photo
    self.pending = pending
    self.at = at
    self.seq = seq
    self.failed = failed
    self.live = live
  }
}

public final class Mouth {
  public private(set) var lines: [ChatLine] = []
  public private(set) var up = false
  public private(set) var hint = ""
  public private(set) var catalog: [SlashCommand] = []
  public private(set) var avatarRev = 0
  public private(set) var backdropRev = 0
  public private(set) var roomTheme = ""
  public private(set) var faceHint = ""
  public private(set) var typingUntil: Int64 = 0
  private let now: () -> Int64

  public init(now: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }) {
    self.now = now
  }

  public func setUp(_ value: Bool) {
    up = value
    if !value {
      dropDraft()
      typingUntil = 0
    }
  }

  public func setHint(_ value: String) {
    hint = value
  }

  public func setFaceHint(_ value: String) {
    faceHint = value
  }

  public func setAvatarRev(_ value: Int) {
    avatarRev = value
  }

  public func setBackdropRev(_ value: Int) {
    backdropRev = value
  }

  public func setRoomTheme(_ value: String) {
    roomTheme = value
  }

  public func add(_ line: ChatLine) {
    lines = capThread(lines + [line], max: threadMax)
  }

  public func replace(lines: [ChatLine], up: Bool, hint: String) {
    self.lines = capThread(lines, max: threadMax)
    self.up = up
    self.hint = hint
    catalog = []
    typingUntil = 0
    backdropRev = 0
    roomTheme = ""
  }

  /// Another room (or human) is coming up; its transcript replays on connect.
  public func clearThread() {
    lines = []
  }

  /**
   Last run's thread from disk. Ids already on the thread win (the mailbox
   got there first); drafts never come back. Mailbox order, then capped.
   Pendant `mergeThread`.
   */
  public func hydrate(_ cached: [ChatLine]) {
    let have = Set(lines.map(\.id))
    let add = cached.filter { !have.contains($0.id) && !isDraftBubble($0.kind) }
    if add.isEmpty {
      return
    }
    lines = capThread((lines + add).sorted { compareThread($0, $1) }, max: threadMax)
  }

  /// - Returns: true when a new turn was painted (not a restamp, draft, or control frame).
  @discardableResult
  public func ingest(_ frame: WireFrame) -> Bool {
    if let rev = faceRev(frame.kind, frame.text) {
      avatarRev = rev
      return false
    }
    if frame.kind == "backdrop" {
      if let rev = frame.rev {
        backdropRev = rev
      }
      return false
    }
    if frame.kind == "theme" {
      switch frame.theme {
      case nil:
        break
      case "":
        roomTheme = ""
      case let id?:
        if let known = knownTheme(id) {
          roomTheme = known
        }
      }
      return false
    }
    if frame.kind == "cmds" {
      catalog = frame.commands ?? []
      return false
    }
    if frame.kind == "error" {
      if !fail(id: frame.id, why: describeSendError(frame.text)) {
        let t = frame.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        hint = t.isEmpty ? "mailbox error" : t
      }
      typingUntil = 0
      return false
    }
    if frame.kind == "typing" {
      typingUntil = now() + typingTtlMs
      return false
    }
    if frame.kind == "draft" {
      applyDraft(frame.text ?? "")
      return false
    }
    if frame.kind == "ack" {
      if let id = frame.id {
        ack(id)
      }
      return false
    }
    if frame.kind == "allow" || frame.kind == "pin" {
      return false
    }
    if clearsTyping(frame.kind) {
      typingUntil = 0
    }
    let fromDraft = frame.kind == "reply" && lines.contains { $0.id == draftId }
    if let id = frame.id, let existing = lines.first(where: { $0.id == id }) {
      let nextSeq = frame.seq ?? existing.seq
      let nextAt = frame.at ?? existing.at
      if nextSeq != existing.seq || nextAt != existing.at {
        var copy = existing
        copy.seq = nextSeq
        copy.at = nextAt
        commit(copy)
      }
      return false
    }
    let text = frame.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let photo = frame.images?.first
    if text.isEmpty && photo == nil && frame.kind != "push" {
      if fromDraft {
        dropDraft()
      }
      return false
    }
    commit(
      ChatLine(
        id: frame.id ?? UUID().uuidString,
        fromYou: frame.kind == "inbound",
        text: text.isEmpty ? (photo != nil ? "" : "(ping)") : text,
        kind: frame.kind,
        photo: photo,
        at: frame.at ?? now(),
        seq: frame.seq,
        live: fromDraft
      )
    )
    return true
  }

  public func ack(_ id: String) {
    lines = lines.map { line in
      var line = line
      if line.id == id && line.pending {
        line.pending = false
      }
      return line
    }
  }

  /**
   A mailbox `error` names the frame it refused when it can (`id`); older
   mailboxes and parse failures cannot, so fall back to your newest bubble
   still marked sending. Same rule as pendant `failInThread`.
   - Returns: false when there was nothing of yours to mark.
   */
  @discardableResult
  public func fail(id: String?, why: String) -> Bool {
    let byId = id.flatMap { want in lines.lastIndex(where: { $0.fromYou && $0.id == want }) } ?? -1
    let at = byId >= 0 ? byId : (lines.lastIndex(where: { $0.fromYou && $0.pending }) ?? -1)
    if at < 0 {
      return false
    }
    lines = lines.enumerated().map { i, line in
      var line = line
      if i == at {
        line.pending = false
        line.failed = why
      }
      return line
    }
    return true
  }

  private func applyDraft(_ text: String) {
    let rest = dropLive(lines.filter { $0.id != draftId })
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      lines = rest
      return
    }
    let prev = lines.first { $0.id == draftId }
    lines = capThread(
      placeInThread(
        rest,
        ChatLine(id: draftId, fromYou: false, text: text, kind: "draft", at: prev?.at ?? now(), live: true)
      ),
      max: threadMax
    )
  }

  private func commit(_ line: ChatLine) {
    let base: [ChatLine]
    if line.kind == "reply" {
      base = lines.filter { $0.id != draftId }
    } else {
      base = lines
    }
    lines = capThread(placeInThread(dropLive(base), line), max: threadMax)
  }

  private func dropLive(_ rows: [ChatLine]) -> [ChatLine] {
    rows.map { row in
      var row = row
      if row.live {
        row.live = false
      }
      return row
    }
  }

  private func dropDraft() {
    let rest = lines.filter { $0.id != draftId }
    if rest.count != lines.count {
      lines = rest
    }
  }
}
