import Foundation

public struct EmojiEntry: Equatable {
  public var emoji: String
  public var name: String
  public var aliases: [String]

  public init(emoji: String, name: String, aliases: [String] = []) {
    self.emoji = emoji
    self.name = name
    self.aliases = aliases
  }
}

public struct EmojiEdit: Equatable {
  public var text: String
  public var cursor: Int

  public init(text: String, cursor: Int) {
    self.text = text
    self.cursor = cursor
  }
}

private struct Row {
  var emoji: String
  var name: String
  var aliases: String?
}

private let rows: [Row] = [
  Row(emoji: "😀", name: "grinning", aliases: "D"),
  Row(emoji: "😃", name: "smiley"),
  Row(emoji: "😄", name: "smile"),
  Row(emoji: "😁", name: "grin"),
  Row(emoji: "😆", name: "laughing", aliases: "xd"),
  Row(emoji: "😅", name: "sweat_smile"),
  Row(emoji: "🤣", name: "rofl"),
  Row(emoji: "😂", name: "joy"),
  Row(emoji: "🙂", name: "slightly_smiling"),
  Row(emoji: "😊", name: "blush"),
  Row(emoji: "😇", name: "innocent"),
  Row(emoji: "😉", name: "wink"),
  Row(emoji: "😍", name: "heart_eyes"),
  Row(emoji: "😘", name: "kissing_heart", aliases: "kiss"),
  Row(emoji: "😋", name: "yum"),
  Row(emoji: "😛", name: "stuck_out_tongue", aliases: "P"),
  Row(emoji: "😜", name: "stuck_out_tongue_winking_eye"),
  Row(emoji: "🤪", name: "zany"),
  Row(emoji: "😎", name: "sunglasses"),
  Row(emoji: "🤓", name: "nerd"),
  Row(emoji: "🧐", name: "monocle"),
  Row(emoji: "🤔", name: "thinking"),
  Row(emoji: "🤨", name: "raised_eyebrow"),
  Row(emoji: "😐", name: "neutral"),
  Row(emoji: "😑", name: "expressionless"),
  Row(emoji: "🙄", name: "rolling_eyes"),
  Row(emoji: "😏", name: "smirk"),
  Row(emoji: "😒", name: "unamused"),
  Row(emoji: "😞", name: "disappointed"),
  Row(emoji: "😔", name: "pensive"),
  Row(emoji: "😕", name: "confused"),
  Row(emoji: "🙁", name: "slightly_frowning"),
  Row(emoji: "☹️", name: "frowning"),
  Row(emoji: "😣", name: "persevere"),
  Row(emoji: "😖", name: "confounded"),
  Row(emoji: "😫", name: "tired"),
  Row(emoji: "😩", name: "weary"),
  Row(emoji: "🥺", name: "pleading"),
  Row(emoji: "😢", name: "cry"),
  Row(emoji: "😭", name: "sob"),
  Row(emoji: "😤", name: "triumph"),
  Row(emoji: "😠", name: "angry"),
  Row(emoji: "😡", name: "rage"),
  Row(emoji: "🤬", name: "cursing"),
  Row(emoji: "😳", name: "flushed"),
  Row(emoji: "🥵", name: "hot"),
  Row(emoji: "🥶", name: "cold"),
  Row(emoji: "😱", name: "scream"),
  Row(emoji: "😨", name: "fearful"),
  Row(emoji: "😰", name: "cold_sweat"),
  Row(emoji: "😥", name: "disappointed_relieved"),
  Row(emoji: "😓", name: "sweat"),
  Row(emoji: "🤗", name: "hugging"),
  Row(emoji: "🤭", name: "hand_over_mouth"),
  Row(emoji: "🤫", name: "shushing"),
  Row(emoji: "🤥", name: "lying"),
  Row(emoji: "😶", name: "no_mouth"),
  Row(emoji: "🫠", name: "melting"),
  Row(emoji: "😴", name: "sleeping", aliases: "zzz"),
  Row(emoji: "🥱", name: "yawn"),
  Row(emoji: "😷", name: "mask"),
  Row(emoji: "🤒", name: "thermometer"),
  Row(emoji: "🤕", name: "head_bandage"),
  Row(emoji: "🤢", name: "nauseated"),
  Row(emoji: "🤮", name: "vomiting"),
  Row(emoji: "🤧", name: "sneezing"),
  Row(emoji: "🥳", name: "partying"),
  Row(emoji: "🥸", name: "disguised"),
  Row(emoji: "🤡", name: "clown"),
  Row(emoji: "👻", name: "ghost"),
  Row(emoji: "💀", name: "skull"),
  Row(emoji: "👽", name: "alien"),
  Row(emoji: "🤖", name: "robot"),
  Row(emoji: "💩", name: "poop", aliases: "hankey,shit"),
  Row(emoji: "🙈", name: "see_no_evil"),
  Row(emoji: "🙉", name: "hear_no_evil"),
  Row(emoji: "🙊", name: "speak_no_evil"),
  Row(emoji: "👋", name: "wave"),
  Row(emoji: "🤚", name: "raised_back_of_hand"),
  Row(emoji: "🖐️", name: "hand"),
  Row(emoji: "✋", name: "raised_hand"),
  Row(emoji: "🖖", name: "vulcan"),
  Row(emoji: "👌", name: "ok_hand", aliases: "ok"),
  Row(emoji: "🤌", name: "pinched_fingers"),
  Row(emoji: "🤏", name: "pinching_hand"),
  Row(emoji: "✌️", name: "v", aliases: "victory"),
  Row(emoji: "🤞", name: "crossed_fingers"),
  Row(emoji: "🫰", name: "hand_with_index_finger_and_thumb_crossed"),
  Row(emoji: "🤟", name: "love_you_gesture"),
  Row(emoji: "🤘", name: "metal"),
  Row(emoji: "🤙", name: "call_me"),
  Row(emoji: "👈", name: "point_left"),
  Row(emoji: "👉", name: "point_right"),
  Row(emoji: "👆", name: "point_up"),
  Row(emoji: "👇", name: "point_down"),
  Row(emoji: "☝️", name: "point_up_2"),
  Row(emoji: "👍", name: "thumbsup", aliases: "+1,thumbs_up"),
  Row(emoji: "👎", name: "thumbsdown", aliases: "-1,thumbs_down"),
  Row(emoji: "✊", name: "fist"),
  Row(emoji: "👊", name: "punch"),
  Row(emoji: "🤛", name: "left_facing_fist"),
  Row(emoji: "🤜", name: "right_facing_fist"),
  Row(emoji: "👏", name: "clap"),
  Row(emoji: "🙌", name: "raised_hands"),
  Row(emoji: "🫶", name: "heart_hands"),
  Row(emoji: "👐", name: "open_hands"),
  Row(emoji: "🤲", name: "palms_up"),
  Row(emoji: "🤝", name: "handshake"),
  Row(emoji: "🙏", name: "pray", aliases: "thanks"),
  Row(emoji: "✍️", name: "writing"),
  Row(emoji: "💅", name: "nail_care"),
  Row(emoji: "🤳", name: "selfie"),
  Row(emoji: "💪", name: "muscle"),
  Row(emoji: "🦾", name: "mechanical_arm"),
  Row(emoji: "🦵", name: "leg"),
  Row(emoji: "🦶", name: "foot"),
  Row(emoji: "👂", name: "ear"),
  Row(emoji: "👃", name: "nose"),
  Row(emoji: "👀", name: "eyes"),
  Row(emoji: "👁️", name: "eye"),
  Row(emoji: "👅", name: "tongue"),
  Row(emoji: "👄", name: "lips"),
  Row(emoji: "🧠", name: "brain"),
  Row(emoji: "🫀", name: "anatomical_heart"),
  Row(emoji: "🦴", name: "bone"),
  Row(emoji: "🤷", name: "shrug", aliases: "person_shrugging"),
  Row(emoji: "🤦", name: "facepalm", aliases: "person_facepalming"),
  Row(emoji: "❤️", name: "heart"),
  Row(emoji: "🧡", name: "orange_heart"),
  Row(emoji: "💛", name: "yellow_heart"),
  Row(emoji: "💚", name: "green_heart"),
  Row(emoji: "💙", name: "blue_heart"),
  Row(emoji: "💜", name: "purple_heart"),
  Row(emoji: "🖤", name: "black_heart"),
  Row(emoji: "🤍", name: "white_heart"),
  Row(emoji: "💔", name: "broken_heart"),
  Row(emoji: "❣️", name: "heart_exclamation"),
  Row(emoji: "💕", name: "two_hearts"),
  Row(emoji: "💖", name: "sparkling_heart"),
  Row(emoji: "💗", name: "heartpulse"),
  Row(emoji: "💘", name: "cupid"),
  Row(emoji: "💝", name: "gift_heart"),
  Row(emoji: "💞", name: "revolving_hearts"),
  Row(emoji: "💟", name: "heart_decoration"),
  Row(emoji: "✨", name: "sparkles"),
  Row(emoji: "⭐", name: "star"),
  Row(emoji: "🌟", name: "star2"),
  Row(emoji: "💫", name: "dizzy"),
  Row(emoji: "🔥", name: "fire"),
  Row(emoji: "💯", name: "100"),
  Row(emoji: "💥", name: "boom", aliases: "collision"),
  Row(emoji: "💢", name: "anger"),
  Row(emoji: "💦", name: "sweat_drops"),
  Row(emoji: "💨", name: "dash"),
  Row(emoji: "🕳️", name: "hole"),
  Row(emoji: "💬", name: "speech", aliases: "speech_balloon"),
  Row(emoji: "👁️‍🗨️", name: "eye_speech"),
  Row(emoji: "💭", name: "thought", aliases: "thought_balloon"),
  Row(emoji: "💤", name: "zzz_symbol"),
  Row(emoji: "🎉", name: "tada", aliases: "party"),
  Row(emoji: "🎊", name: "confetti"),
  Row(emoji: "🎈", name: "balloon"),
  Row(emoji: "🎁", name: "gift"),
  Row(emoji: "🏆", name: "trophy"),
  Row(emoji: "🥇", name: "first_place", aliases: "medal"),
  Row(emoji: "🥈", name: "second_place"),
  Row(emoji: "🥉", name: "third_place"),
  Row(emoji: "✅", name: "white_check_mark", aliases: "check"),
  Row(emoji: "❌", name: "x", aliases: "cross"),
  Row(emoji: "⚠️", name: "warning"),
  Row(emoji: "❓", name: "question"),
  Row(emoji: "❗", name: "exclamation"),
  Row(emoji: "💡", name: "bulb"),
  Row(emoji: "📌", name: "pushpin", aliases: "pin"),
  Row(emoji: "📍", name: "round_pushpin"),
  Row(emoji: "📝", name: "memo"),
  Row(emoji: "🔔", name: "bell"),
  Row(emoji: "🔑", name: "key"),
  Row(emoji: "🔒", name: "lock"),
  Row(emoji: "🔓", name: "unlock"),
  Row(emoji: "🔗", name: "link"),
  Row(emoji: "📎", name: "paperclip"),
  Row(emoji: "📷", name: "camera"),
  Row(emoji: "📸", name: "camera_flash"),
  Row(emoji: "💻", name: "computer"),
  Row(emoji: "📱", name: "phone", aliases: "iphone"),
  Row(emoji: "📧", name: "email", aliases: "mail"),
  Row(emoji: "📚", name: "books", aliases: "book"),
  Row(emoji: "✏️", name: "pencil"),
  Row(emoji: "✂️", name: "scissors"),
  Row(emoji: "🔨", name: "hammer"),
  Row(emoji: "🔧", name: "wrench"),
  Row(emoji: "🗑️", name: "trash"),
  Row(emoji: "🚀", name: "rocket"),
  Row(emoji: "🚗", name: "car"),
  Row(emoji: "✈️", name: "airplane"),
  Row(emoji: "🏠", name: "house"),
  Row(emoji: "🌍", name: "earth", aliases: "globe"),
  Row(emoji: "☀️", name: "sunny", aliases: "sun"),
  Row(emoji: "🌙", name: "moon"),
  Row(emoji: "☁️", name: "cloud"),
  Row(emoji: "🌈", name: "rainbow"),
  Row(emoji: "❄️", name: "snowflake"),
  Row(emoji: "💧", name: "droplet"),
  Row(emoji: "⚡", name: "zap"),
  Row(emoji: "☕", name: "coffee"),
  Row(emoji: "🍺", name: "beer"),
  Row(emoji: "🍕", name: "pizza"),
  Row(emoji: "🍔", name: "hamburger", aliases: "burger"),
  Row(emoji: "🍟", name: "fries"),
  Row(emoji: "🌮", name: "taco"),
  Row(emoji: "🍣", name: "sushi"),
  Row(emoji: "🍪", name: "cookie"),
  Row(emoji: "🎂", name: "birthday", aliases: "cake"),
  Row(emoji: "🍰", name: "cake_slice"),
  Row(emoji: "🍎", name: "apple"),
  Row(emoji: "🌹", name: "rose"),
  Row(emoji: "🌻", name: "sunflower"),
  Row(emoji: "🌵", name: "cactus"),
  Row(emoji: "🌳", name: "tree"),
  Row(emoji: "🐶", name: "dog"),
  Row(emoji: "🐱", name: "cat"),
  Row(emoji: "🦊", name: "fox"),
  Row(emoji: "🐻", name: "bear"),
  Row(emoji: "🐼", name: "panda"),
  Row(emoji: "🦄", name: "unicorn"),
  Row(emoji: "🐝", name: "bee"),
  Row(emoji: "🐢", name: "turtle"),
  Row(emoji: "🐙", name: "octopus"),
  Row(emoji: "🦋", name: "butterfly"),
  Row(emoji: "🐞", name: "bug"),
]

private func aliasesOf(_ raw: String?) -> [String] {
  guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else {
    return []
  }
  return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
    .filter { !$0.isEmpty }
}

public let emojiCatalog: [EmojiEntry] = rows.map {
  EmojiEntry(emoji: $0.emoji, name: $0.name, aliases: aliasesOf($0.aliases))
}

private func normName(_ name: String) -> String {
  name.lowercased().replacingOccurrences(of: "-", with: "_")
}

private let byName: [String: String] = {
  var map: [String: String] = [:]
  for entry in emojiCatalog {
    map[normName(entry.name)] = entry.emoji
    for alias in entry.aliases {
      map[normName(alias)] = entry.emoji
    }
  }
  return map
}()

public func emojiForShortcode(_ name: String) -> String? {
  byName[normName(name)]
}

private let defaultPick = [
  "grinning", "smile", "joy", "blush", "wink", "heart_eyes", "thinking", "sunglasses",
  "cry", "sob", "rage", "scream", "partying", "shrug", "facepalm", "thumbsup", "thumbsdown",
  "ok_hand", "clap", "pray", "wave", "muscle", "heart", "fire", "100", "tada", "sparkles",
  "star", "white_check_mark", "x", "warning", "eyes", "poop", "skull", "ghost", "robot",
  "dog", "cat", "rocket", "coffee", "pizza", "sunny", "moon", "zap",
]

public func searchEmoji(_ query: String) -> [EmojiEntry] {
  let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: ":", with: "")
  if q.isEmpty {
    return defaultPick.compactMap { name in emojiCatalog.first { $0.name == name } }
  }
  let exact = query.trimmingCharacters(in: .whitespacesAndNewlines)
  return emojiCatalog.filter { entry in
    entry.name.contains(q) || entry.aliases.contains { $0.contains(q) } || entry.emoji == exact
  }
}

private struct Span {
  var start: Int
  var end: Int
  var value: String
}

private struct Emoticon {
  var token: String
  var emoji: String
  var hold: Bool
}

private let shortcodeRe = try! NSRegularExpression(pattern: ":[a-z0-9_+-]{1,32}:", options: [.caseInsensitive])

private let emoticons: [Emoticon] = [
  Emoticon(token: ":'(", emoji: "😢", hold: false),
  Emoticon(token: ":-D", emoji: "😀", hold: true),
  Emoticon(token: ":-P", emoji: "😛", hold: true),
  Emoticon(token: ":-O", emoji: "😮", hold: true),
  Emoticon(token: ":-)", emoji: "😊", hold: false),
  Emoticon(token: ":-(", emoji: "🙁", hold: false),
  Emoticon(token: ";-)", emoji: "😉", hold: false),
  Emoticon(token: ":D", emoji: "😀", hold: true),
  Emoticon(token: ":P", emoji: "😛", hold: true),
  Emoticon(token: ":O", emoji: "😮", hold: true),
  Emoticon(token: ":)", emoji: "😊", hold: false),
  Emoticon(token: ":(", emoji: "🙁", hold: false),
  Emoticon(token: ";)", emoji: "😉", hold: false),
  Emoticon(token: ":/", emoji: "😕", hold: false),
  Emoticon(token: ":|", emoji: "😐", hold: false),
  Emoticon(token: "xD", emoji: "😆", hold: true),
]

/// UTF-16 length, matching Java/Kotlin `String.length` so cursor math is the same.
private func u16Len(_ s: String) -> Int {
  (s as NSString).length
}

private func u16Slice(_ s: String, start: Int, end: Int) -> String {
  let ns = s as NSString
  let loc = max(0, start)
  let endClamped = min(end, ns.length)
  let len = max(0, endClamped - loc)
  return ns.substring(with: NSRange(location: loc, length: len))
}

private func u16Char(_ s: String, at: Int) -> unichar? {
  let ns = s as NSString
  if at < 0 || at >= ns.length {
    return nil
  }
  return ns.character(at: at)
}

private func isWhitespaceU16(_ ch: unichar) -> Bool {
  guard let scalar = UnicodeScalar(ch) else {
    return false
  }
  return CharacterSet.whitespacesAndNewlines.contains(scalar)
}

private func isBreakBefore(_ text: String, index: Int) -> Bool {
  if index == 0 {
    return true
  }
  guard let ch = u16Char(text, at: index - 1) else {
    return true
  }
  return isWhitespaceU16(ch) || ch == 0x28  // '('
}

private func isTerminator(_ ch: unichar?, hold: Bool, trailing: Bool) -> Bool {
  guard let ch else {
    return trailing || !hold
  }
  return isWhitespaceU16(ch) || ch == 0x2E || ch == 0x2C || ch == 0x21 || ch == 0x3F || ch == 0x3B
    || ch == 0x29
}

private func shortcodeSpans(_ text: String) -> [Span] {
  let ns = text as NSString
  let matches = shortcodeRe.matches(in: text, range: NSRange(location: 0, length: ns.length))
  var spans: [Span] = []
  for match in matches {
    let raw = ns.substring(with: match.range)
    let name = String(raw.dropFirst().dropLast())
    guard let emoji = emojiForShortcode(name) else {
      continue
    }
    spans.append(Span(start: match.range.location, end: match.range.location + match.range.length, value: emoji))
  }
  return spans
}

private func overlaps(_ spans: [Span], start: Int, end: Int) -> Bool {
  spans.contains { start < $0.end && end > $0.start }
}

private func emoticonSpans(_ text: String, trailing: Bool, blocked: [Span]) -> [Span] {
  var spans: [Span] = []
  var i = 0
  let n = u16Len(text)
  while i < n {
    if !isBreakBefore(text, index: i) || overlaps(blocked, start: i, end: i + 1) {
      i += 1
      continue
    }
    var hit: Span?
    for item in emoticons {
      let end = i + u16Len(item.token)
      if end > n {
        continue
      }
      let slice = u16Slice(text, start: i, end: end)
      if slice.caseInsensitiveCompare(item.token) != .orderedSame {
        continue
      }
      if overlaps(blocked, start: i, end: end) {
        continue
      }
      if !isTerminator(u16Char(text, at: end), hold: item.hold, trailing: trailing) {
        continue
      }
      hit = Span(start: i, end: end, value: item.emoji)
      break
    }
    if let hit {
      spans.append(hit)
      i = hit.end
      continue
    }
    i += 1
  }
  return spans
}

private func applySpans(_ text: String, cursor: Int, spans: [Span]) -> EmojiEdit {
  if spans.isEmpty {
    return EmojiEdit(text: text, cursor: cursor)
  }
  var out = ""
  var nextCursor = cursor
  var last = 0
  var parked = false
  for span in spans {
    out += u16Slice(text, start: last, end: span.start)
    let at = u16Len(out)
    out += span.value
    if !parked {
      if cursor >= span.end {
        nextCursor += u16Len(span.value) - (span.end - span.start)
      } else if cursor > span.start {
        nextCursor = at + u16Len(span.value)
        parked = true
      }
    }
    last = span.end
  }
  out += u16Slice(text, start: last, end: u16Len(text))
  let doneLen = u16Len(out)
  return EmojiEdit(text: out, cursor: min(max(nextCursor, 0), doneLen))
}

public func applyEmoji(_ text: String, cursor: Int, whenTo: String) -> EmojiEdit {
  let safeCursor = min(max(cursor, 0), u16Len(text))
  let codes = shortcodeSpans(text)
  let faces = emoticonSpans(text, trailing: whenTo == "send", blocked: codes)
  let spans = (codes + faces).sorted { $0.start < $1.start }
  return applySpans(text, cursor: safeCursor, spans: spans)
}
