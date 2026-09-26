import Foundation

public let speakBytesMax = 4_000

public func speakable(_ markdown: String) -> String {
  let src = replaceFences(markdown)
  var parts: [String] = []
  for rawLine in src.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
    var line = String(rawLine)
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("|") || isRule(trimmed) {
      continue
    }
    line = line.replacingOccurrences(of: "<br>", with: "", options: .caseInsensitive)
    line = line.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    line = replaceImages(line)
    line = replaceLinks(line)
    line = line.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
    line = line.replacingOccurrences(of: #"^>\s?"#, with: "", options: .regularExpression)
    line = line.replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
    line = line.replacingOccurrences(of: #"^\s*\d+\.\s+"#, with: "", options: .regularExpression)
    line = stripMarks(line)
    line = dropEmoji(line)
    line = line.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
    line = line.trimmingCharacters(in: .whitespaces)
    if !line.isEmpty {
      parts.append(line)
    }
  }
  return parts.joined(separator: "\n")
}

public func clipForSpeech(_ text: String, maxBytes: Int = speakBytesMax) -> String {
  if Array(text.utf8).count <= maxBytes {
    return text
  }
  var out = ""
  let chunks = speechChunks(text)
  for sentence in chunks {
    let next = out.isEmpty ? sentence : "\(out) \(sentence)"
    if Array(next.utf8).count > maxBytes {
      break
    }
    out = next
  }
  if !out.isEmpty {
    return out
  }
  return capUtf8(text, maxBytes: maxBytes)
}

func speechChunks(_ text: String) -> [String] {
  var out: [String] = []
  var current = ""
  let scalars = Array(text)
  var i = 0
  while i < scalars.count {
    let ch = scalars[i]
    current.append(ch)
    if ch == "." || ch == "!" || ch == "?" {
      var j = i + 1
      var broke = false
      while j < scalars.count && scalars[j].isWhitespace {
        broke = true
        j += 1
      }
      if broke || j >= scalars.count {
        out.append(current.trimmingCharacters(in: .whitespaces))
        current = ""
        i = j
        continue
      }
    }
    if ch.isNewline {
      let bit = current.trimmingCharacters(in: .whitespacesAndNewlines)
      if !bit.isEmpty {
        out.append(bit)
      }
      current = ""
    }
    i += 1
  }
  let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
  if !tail.isEmpty {
    out.append(tail)
  }
  return out
}

public func isEmojiPart(_ cp: UInt32) -> Bool {
  switch cp {
  case 0x200D, 0xFE0E, 0xFE0F, 0x20E3:
    return true
  case 0x00A9, 0x00AE, 0x203C, 0x2049, 0x2122, 0x2139, 0x24C2, 0x25B6, 0x25C0:
    return true
  case 0x2934, 0x2935, 0x3030, 0x303D, 0x3297, 0x3299:
    return true
  case 0x2194...0x2199, 0x21A9...0x21AA, 0x25AA...0x25AB, 0x25FB...0x25FE:
    return true
  case 0x2300...0x23FF, 0x2600...0x27BF, 0x2B00...0x2BFF:
    return true
  case 0x1F000...0x1FAFF, 0x1FC00...0x1FFFD:
    return true
  default:
    return false
  }
}

private func replaceFences(_ src: String) -> String {
  src.replacingOccurrences(
    of: #"```[^\n]*\n[\s\S]*?```"#,
    with: "\ncode\n",
    options: .regularExpression
  )
}

private func isRule(_ line: String) -> Bool {
  if line.count < 3 {
    return false
  }
  return line.allSatisfy { $0 == "-" || $0 == "*" || $0 == "_" }
}

private func replaceImages(_ line: String) -> String {
  line.replacingOccurrences(of: #"!\[[^\]]*\]\([^)]*\)"#, with: "photo", options: .regularExpression)
}

private func replaceLinks(_ line: String) -> String {
  line.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
}

private func stripMarks(_ line: String) -> String {
  var s = line
  let pairs = ["~~", "**", "__", "`", "*", "_"]
  for mark in pairs {
    s = s.replacingOccurrences(of: mark, with: "")
  }
  return s
}

private func dropEmoji(_ line: String) -> String {
  var out = ""
  for scalar in line.unicodeScalars {
    if !isEmojiPart(scalar.value) {
      out.unicodeScalars.append(scalar)
    }
  }
  return out
}
