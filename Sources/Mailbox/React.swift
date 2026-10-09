import Foundation

/// Emoji on a bubble, both ways. `{ kind: "react", id, text }` — empty text clears.
/// Not a turn: no phone queue, no cursor.
public let reactionPalette = ["👍", "👎", "❤️", "🔥", "🤣", "😢", "🤔", "🙏", "👀", "🎉", "💯", "👏"]

/// Emoji per palette row on the long-press menu. Two rows of six, like Tapback.
public let reactionRowMax = 6

public func reactionRows(_ palette: [String]) -> [[String]] {
  stride(from: 0, to: palette.count, by: reactionRowMax).map {
    Array(palette[$0..<min($0 + reactionRowMax, palette.count)])
  }
}

public let reactionTextMax = 64

public func parseReactionText(_ raw: String?) -> String? {
  guard let raw else {
    return ""
  }
  let text = raw.split { $0.isWhitespace }.joined(separator: " ")
  if text.isEmpty {
    return ""
  }
  for scalar in text.unicodeScalars {
    if scalar.value == 0x200D || scalar.value == 0xFE0F {
      continue
    }
    switch scalar.properties.generalCategory {
    case .control, .format:
      return nil
    default:
      break
    }
  }
  if Array(text.utf8).count > reactionTextMax {
    return nil
  }
  return text
}

public func toggleReaction(_ current: String?, _ emoji: String) -> String {
  current == emoji ? "" : emoji
}

public func canReact(fromYou: Bool, kind: String?, id: String) -> Bool {
  !fromYou && (kind == "reply" || kind == "push") && !id.isEmpty
}

/// Emoji rows: Kit's `reply` / `push`, socket live. Down, a pick could not send.
public func showsReactions(fromYou: Bool, kind: String?, id: String, up: Bool) -> Bool {
  up && canReact(fromYou: fromYou, kind: kind, id: id)
}

/// First row of the bubble menu. The raw markdown goes on the pasteboard.
public let copyTextLabel = "Copy text"

/// Any bubble with words — yours too, socket down too. A photo-only bubble has no copy row.
public func canCopy(_ text: String) -> Bool {
  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

/// Hold opens the bubble menu when it would have a row.
public func canHold(fromYou: Bool, kind: String?, id: String, text: String, up: Bool) -> Bool {
  canCopy(text) || showsReactions(fromYou: fromYou, kind: kind, id: id, up: up)
}

public func reactFrame(id: String, text: String) -> WireFrame {
  WireFrame(kind: "react", text: text, id: id)
}
