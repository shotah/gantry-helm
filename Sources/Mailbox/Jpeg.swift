import Foundation

public let avatarMaxBytes = 5 * 1024 * 1024
public let avatarEdge = 1280

public enum JpegCheck: Equatable {
  case ok
  case err(detail: String)

  public var ok: Bool {
    if case .ok = self { return true }
    return false
  }
}

public func acceptJpeg(_ bytes: Data) -> JpegCheck {
  if bytes.count < 32 {
    return .err(detail: "image too small")
  }
  if bytes.count > avatarMaxBytes {
    return .err(detail: "image too large (max 5MB)")
  }
  let b = [UInt8](bytes.prefix(3))
  if b.count < 3 || b[0] != 0xFF || b[1] != 0xD8 || b[2] != 0xFF {
    return .err(detail: "need a JPEG (the console converts PNG/WebP on upload)")
  }
  return .ok
}

public func shouldPassthroughJpeg(
  type: String,
  size: Int,
  width: Int,
  height: Int,
  edge: Int = avatarEdge,
  maxBytes: Int = avatarMaxBytes
) -> Bool {
  let limit = max(edge, 1)
  let longest = max(max(width, height), 1)
  let scale = min(1.0, Double(limit) / Double(longest))
  return type == "image/jpeg" && scale == 1.0 && size <= maxBytes
}
