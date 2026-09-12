/// Mailbox `kind: "error"` frames carry a short wire token in `text` (`rate`,
/// `too large`, `bad frame`). Paint a sentence under your own bubble. Same
/// strings as pendant `lib/phone/sendError.ts`.
public func describeSendError(_ text: String?) -> String {
  switch text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
  case "rate":
    return "Not sent — too much too fast. Wait a minute, then try again."
  case "too large":
    return "Not sent — too big for the room."
  default:
    return "Not sent."
  }
}

/// Photo failed before the wire: the shrink ladder bottomed out, or the decoder gave up.
public func describePhotoError(_ error: String) -> String {
  if error == "too large" {
    return "Photo not sent — still too big after shrinking."
  }
  return "Photo not sent — couldn't read that image."
}

/// `jpegFromUri` throws pendant's messages; fold them to the two wire-side tokens.
public func photoErrorToken(_ message: String?) -> String {
  if (message ?? "").contains("too large") {
    return "too large"
  }
  return "bad photo"
}
