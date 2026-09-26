import Foundation

public enum SpeakPhase: Equatable {
  case idle
  case fetching
  case playing
}

public enum SpeakFail: Equatable {
  case empty
  case offline
  case noVoice
  case unauthorized
  case busy
  case vendor
  case play
}

public func speakFailFromStatus(_ status: Int) -> SpeakFail {
  switch status {
  case 404:
    return .noVoice
  case 401, 403:
    return .unauthorized
  case 429:
    return .busy
  default:
    return .vendor
  }
}

public func speakStatus(_ phase: SpeakPhase) -> String {
  switch phase {
  case .fetching:
    return "voice…"
  case .playing:
    return "speaking"
  case .idle:
    return ""
  }
}

public func speakBarLabel(_ phase: SpeakPhase) -> String {
  switch phase {
  case .fetching:
    return "Fetching voice…"
  case .playing:
    return "Speaking · hold to cut in"
  case .idle:
    return ""
  }
}

public func speakFailHint(_ reason: SpeakFail) -> String {
  switch reason {
  case .noVoice:
    return "Kit's voice is off on this Worker (no TTS key, or VOICE=off)."
  case .unauthorized:
    return "Kit's voice: sign in again."
  case .busy:
    return "Kit's voice: too many requests, try again in a moment."
  case .vendor:
    return
      "Kit's voice failed at Google. Check the Cloud Text-to-Speech API and the key restriction."
  case .offline:
    return "Kit's voice: could not reach the Worker."
  case .play:
    return "Kit's voice: the phone would not play it. Hold again."
  case .empty:
    return ""
  }
}

public func speaksReply(kind: String?, replay: Bool, fresh: Bool, armed: Bool) -> Bool {
  armed && fresh && !replay && kind == "reply"
}

public func disarmsVoice(_ kind: String?) -> Bool {
  kind == "error"
}

public func voiceBarShown(offered: Bool, on: Bool) -> Bool {
  offered && on
}
