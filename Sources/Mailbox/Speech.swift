import Foundation

public let listenEndMs: Int64 = 2_000

public enum HoldState: Equatable {
  case idle
  case listening
  case finishing
  case blocked
}

public func holdLabel(_ state: HoldState) -> String {
  switch state {
  case .idle:
    return "Hold to talk"
  case .listening:
    return "Release to send"
  case .finishing:
    return "…"
  case .blocked:
    return "Mic blocked"
  }
}

private func tidySpoken(_ s: String) -> String {
  s.split { $0.isWhitespace }.joined(separator: " ")
}

func growsSpoken(_ earlier: String, _ later: String) -> Bool {
  let a = tidySpoken(earlier).lowercased()
  let b = tidySpoken(later).lowercased()
  if a.isEmpty || b.isEmpty {
    return false
  }
  if a == b {
    return true
  }
  if !b.hasPrefix(a) {
    return false
  }
  let next = b[b.index(b.startIndex, offsetBy: a.count)]
  return next == " " || ".,!?;:')]".contains(next)
}

func foldSpoken(_ parts: inout [String], _ next: String) {
  let t = tidySpoken(next)
  if t.isEmpty {
    return
  }
  guard let last = parts.last else {
    parts.append(t)
    return
  }
  if growsSpoken(last, t) {
    parts[parts.count - 1] = t
    return
  }
  if growsSpoken(t, last) {
    return
  }
  parts.append(t)
}

public func spokenFrom(_ finals: [String], interim: String = "") -> String {
  var parts: [String] = []
  for f in finals {
    foldSpoken(&parts, f)
  }
  if !tidySpoken(interim).isEmpty {
    foldSpoken(&parts, interim)
  }
  return tidySpoken(parts.joined(separator: " "))
}

public final class Utterance {
  private let onDone: (String) -> Void
  private var finals: [String] = []
  private var interim = ""
  public private(set) var ended = false

  public init(onDone: @escaping (String) -> Void) {
    self.onDone = onDone
  }

  public var heard: String {
    spokenFrom(finals, interim: interim)
  }

  public func partial(_ text: String) {
    if !ended {
      interim = text
    }
  }

  public func final(_ text: String) {
    if ended {
      return
    }
    foldSpoken(&finals, text)
    interim = ""
  }

  public func finish() {
    if ended {
      return
    }
    ended = true
    onDone(heard)
  }

  public func abort() {
    if ended {
      return
    }
    finals = []
    interim = ""
    finish()
  }
}
