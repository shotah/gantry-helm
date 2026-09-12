/// Mirror ai-gantry `stripHarnessContext` / pendant `lib/phone/text.ts`.
private let harnessPrefixes = [
  "[harness]",
  "[location",
  "[current time]",
  "[hours]",
  "[memory]",
]

private func harnessTagLine(_ line: String) -> Bool {
  let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
  return harnessPrefixes.contains { t.hasPrefix($0) }
}

private func harnessBlock(_ part: String) -> Bool {
  for line in part.split(separator: "\n", omittingEmptySubsequences: false) {
    let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty {
      continue
    }
    return harnessTagLine(String(t))
  }
  return false
}

private func stripTrailingHarnessLines(_ part: String) -> String {
  let lines = part.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
  for i in lines.indices {
    if !harnessTagLine(lines[i]) {
      continue
    }
    if i == 0 {
      return part
    }
    return lines[..<i].joined(separator: "\n")
  }
  return part
}

/// Drop pasted / old-client clock and hydration blocks so they are not stored as speech.
public func stripHarnessContext(_ raw: String) -> String {
  let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
  if s.isEmpty {
    return ""
  }
  var kept: [String] = []
  for part in s.components(separatedBy: "\n\n") {
    if harnessBlock(part) {
      continue
    }
    var trimmed = stripTrailingHarnessLines(part)
    while trimmed.hasSuffix("\n") {
      trimmed.removeLast()
    }
    if trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      continue
    }
    kept.append(trimmed)
  }
  return kept.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
}
