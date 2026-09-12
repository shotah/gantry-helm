import Foundation

/// Pendant caps `utf8Bytes(url)` of the whole `data:` URL, not the JPEG inside it.
public let imageBytesMax = 1_500_000
public let chatPhotoEdge = 1600
private let imageB64Max = imageBytesMax / 3 * 4 + 64

/**
 Raw JPEG budget. Base64 is 4/3 of the bytes plus the `data:image/jpeg;base64,`
 prefix, so encode to this, not `imageBytesMax`. Mirrors pendant `lib/phone/photo.ts`.
 */
public let photoJpegBytesMax = (imageBytesMax - 32) / 4 * 3

/// Quality ladder per edge, then the edge shrinks by `jpegEdgeStep` until `jpegEdgeMin`.
public let jpegQualitySteps = [90, 80, 70, 60]
public let jpegEdgeStep = 0.75
public let jpegEdgeMin = 320

/**
 Settings → Photo size. Long edge in px. Vision models bill by pixel area
 (~w·h/750 tokens) and clamp near 1 MP, so Full mostly buys wire bytes, not
 detail. Same ids and edges as the pendant PWA so "Medium" means one thing.
 */
public struct PhotoSize: Equatable {
  public var id: String
  public var label: String
  public var edge: Int
}

public let photoSizes = [
  PhotoSize(id: "full", label: "Full", edge: chatPhotoEdge),
  PhotoSize(id: "medium", label: "Medium", edge: 1024),
  PhotoSize(id: "small", label: "Small", edge: 640),
]
public let photoSizeIds = photoSizes.map(\.id)
public let defaultPhotoSize = "medium"

private let allowed = Set(["image/jpeg", "image/jpg", "image/png", "image/webp"])

/// One JPEG encode on the ladder: longest edge in px and compress quality.
public struct JpegStep: Equatable {
  public var edge: Int
  public var quality: Int

  public init(edge: Int, quality: Int) {
    self.edge = edge
    self.quality = quality
  }
}

public enum PhotoResult: Equatable {
  case ok(url: String)
  case err(error: String)

  public var ok: Bool {
    if case .ok = self { return true }
    return false
  }
}

public func parsePhotoSize(_ v: String?) -> String {
  if let v, photoSizeIds.contains(v) {
    return v
  }
  return defaultPhotoSize
}

private func photoSize(_ id: String?) -> PhotoSize {
  let want = parsePhotoSize(id)
  return photoSizes.first { $0.id == want }!
}

/// Java / Kotlin `roundToInt`: half away from zero toward +∞ (`floor(x + 0.5)`).
func roundHalfUp(_ x: Double) -> Int {
  Int((x + 0.5).rounded(.down))
}

public func photoEdge(_ id: String?) -> Int {
  photoSize(id).edge
}

public func photoSizeLabel(_ id: String?) -> String {
  photoSize(id).label
}

/// Settings chip text, same as the PWA `<option>`: "Medium · 1024 px".
public func photoSizeChip(_ id: String?) -> String {
  let s = photoSize(id)
  return "\(s.label) · \(s.edge) px"
}

/**
 Encode attempts, biggest first. Draw at `min(edge, longest)` (never upscale),
 walk `jpegQualitySteps`, then edge × `jpegEdgeStep` and repeat until the
 next edge would drop under `jpegEdgeMin`. Mirrors pendant `jpegFromFile`.
 */
public func shrinkSteps(edge: Int, longest: Int) -> [JpegStep] {
  var out: [JpegStep] = []
  var target = max(min(edge, longest), 1)
  while true {
    for q in jpegQualitySteps {
      out.append(JpegStep(edge: target, quality: q))
    }
    let next = roundHalfUp(Double(target) * jpegEdgeStep)
    if next < jpegEdgeMin {
      break
    }
    target = next
  }
  return out
}

/// First `steps` encode that fits `maxBytes`, or nil when even the smallest is over.
public func shrinkToFit(
  _ steps: [JpegStep],
  maxBytes: Int,
  encode: (JpegStep) -> Data
) -> Data? {
  for step in steps {
    let bytes = encode(step)
    if bytes.count <= maxBytes {
      return bytes
    }
  }
  return nil
}

public func photoDataUrl(_ bytes: Data, mime: String = "image/jpeg") -> PhotoResult {
  var kind = mime.lowercased()
  if kind == "image/jpg" {
    kind = "image/jpeg"
  }
  if !allowed.contains(kind) {
    return .err(error: "bad photo")
  }
  if bytes.isEmpty {
    return .err(error: "bad photo")
  }
  if bytes.count > photoJpegBytesMax {
    return .err(error: "too large")
  }
  let b64 = bytes.base64EncodedString()
  return .ok(url: "data:\(kind);base64,\(b64)")
}

/**
 Attach encodes and holds; Send emits one inbound. Empty caption is allowed
 when a photo is staged. Same rule as pendant Compose (`!t && !photo`).
 */
public func composeHasTurn(text: String, photo: String?) -> Bool {
  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(photo ?? "").isEmpty
}

public func parsePhotoFile(type: String, size: Int) -> PhotoResult {
  let kind = type.lowercased()
  if !allowed.contains(kind) {
    return .err(error: "bad photo")
  }
  if size <= 0 {
    return .err(error: "bad photo")
  }
  if size > imageBytesMax {
    return .err(error: "too large")
  }
  return .ok(url: "")
}

public func decodeDataUrl(_ url: String) -> Data? {
  let marker = "base64,"
  guard let i = url.range(of: marker), url.hasPrefix("data:image/") else {
    return nil
  }
  let b64 = url[i.upperBound...].replacingOccurrences(of: "\n", with: "")
  if b64.count > imageB64Max {
    return nil
  }
  guard let bytes = Data(base64Encoded: String(b64), options: [.ignoreUnknownCharacters]) else {
    return nil
  }
  return bytes.count <= imageBytesMax ? bytes : nil
}
