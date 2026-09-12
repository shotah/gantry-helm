import Foundation

/// Last JPEG plus the rev that names it (0 = unknown).
public struct CachedBlob: Equatable {
  public var rev: Int
  public var bytes: Data

  public init(rev: Int, bytes: Data) {
    self.rev = rev
    self.bytes = bytes
  }
}

/**
 Last JPEG per room on disk, so the face and wallpaper paint on launch
 before the mailbox answers. Every launch still asks, with
 `If-None-Match: "<rev>"`. Rev is written last: a fresh rev on stale
 bytes would 304 forever.
 */
public final class BlobCache {
  private let dir: URL

  public init(dir: URL) {
    self.dir = dir
  }

  public func read(_ key: String) -> CachedBlob? {
    let file = dir.appendingPathComponent(key)
    guard let bytes = try? Data(contentsOf: file), !bytes.isEmpty else {
      return nil
    }
    return CachedBlob(rev: rev(key), bytes: bytes)
  }

  /// Rev of the bytes on disk without reading them; 0 when none or unknown.
  public func rev(_ key: String) -> Int {
    let file = dir.appendingPathComponent(key)
    guard FileManager.default.fileExists(atPath: file.path) else {
      return 0
    }
    let revFile = dir.appendingPathComponent("\(key).rev")
    guard let raw = try? String(contentsOf: revFile, encoding: .utf8),
      let n = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
      n > 0
    else {
      return 0
    }
    return n
  }

  /// Nil or empty forgets the room's blob (the mailbox said 404).
  public func write(_ key: String, _ blob: CachedBlob?) {
    let fm = FileManager.default
    let file = dir.appendingPathComponent(key)
    let revFile = dir.appendingPathComponent("\(key).rev")
    try? fm.removeItem(at: revFile)
    if blob == nil || blob?.bytes.isEmpty == true {
      try? fm.removeItem(at: file)
      return
    }
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let tmp = dir.appendingPathComponent("\(key).tmp")
    do {
      try blob!.bytes.write(to: tmp, options: .atomic)
      if fm.fileExists(atPath: file.path) {
        try fm.removeItem(at: file)
      }
      try fm.moveItem(at: tmp, to: file)
      if blob!.rev > 0 {
        try String(blob!.rev).write(to: revFile, atomically: true, encoding: .utf8)
      }
    } catch {
      try? fm.removeItem(at: tmp)
    }
  }
}

/// Stable file name per blob path + origin + room: `api-avatar-<16 hex>`. No rev or bearer.
public func blobCacheKey(origin: String, slug: String, path: String) -> String {
  let kind = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    .replacingOccurrences(of: "/", with: "-")
  return "\(kind)-\(fnv1a64Hex("\(httpOrigin(origin))|\(slug)"))"
}

func fnv1a64Hex(_ s: String) -> String {
  var h: UInt64 = 0xcbf2_9ce4_8422_2325
  for b in s.utf8 {
    h ^= UInt64(b)
    h = h &* 0x100_0000_01b3
  }
  return String(format: "%016llx", h)
}
