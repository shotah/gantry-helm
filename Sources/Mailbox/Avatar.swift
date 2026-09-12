import Foundation

public func displaySlug(_ slug: String) -> String {
  let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
  if s.isEmpty {
    return "Kit"
  }
  guard let first = s.first else {
    return "Kit"
  }
  return String(first).uppercased() + s.dropFirst()
}

public func faceRev(_ kind: String?, _ text: String?) -> Int? {
  guard kind == "face" else {
    return nil
  }
  guard let t = text, let n = Int64(t) else {
    return nil
  }
  return n > 0 ? Int(n) : nil
}

/// `rev` 0 = cleared. Junk (missing, negative, not an int) is not a backdrop notice.
public func backdropRev(_ kind: String?, _ raw: Any?) -> Int? {
  guard kind == "backdrop" else {
    return nil
  }
  guard let n = jsonWholeNumber(raw) else {
    return nil
  }
  if n < 0 || n > Int64(Int.max) {
    return nil
  }
  return Int(n)
}

/**
 Known id, empty string when cleared, null when this is not a theme notice (or junk).
 Mirrors pendant `themeIdFromUnknown`.
 */
public func roomThemeNotice(
  _ kind: String?,
  themePresent: Bool,
  themeNull: Bool,
  themeRaw: String?
) -> String? {
  guard kind == "theme" else {
    return nil
  }
  if !themePresent || themeNull {
    return ""
  }
  return knownTheme(themeRaw)
}

/// `If-None-Match` for a blob we hold; pendant `blobEtag`.
public func blobEtag(_ rev: Int) -> String {
  "\"\(rev)\""
}

/// Rev a blob GET names itself with: `X-Pendant-Rev`, else the `ETag` digits. 0 = unknown.
public func blobRev(_ xRev: String?, etag: String?) -> Int {
  if let x = xRev?.trimmingCharacters(in: .whitespacesAndNewlines), let n = Int(x), n > 0 {
    return n
  }
  var tag = etag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  if tag.hasPrefix("W/") {
    tag = String(tag.dropFirst(2))
  }
  tag = tag.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
  if let n = Int(tag), n > 0 {
    return n
  }
  return 0
}

public func blobUrl(_ origin: String, path: String, slug: String, rev: Int = 0) -> String {
  let base = "\(httpOrigin(origin))\(path)?slug=\(slug)"
  return rev > 0 ? "\(base)&v=\(rev)" : base
}

public func avatarUrl(_ origin: String, slug: String, rev: Int = 0) -> String {
  blobUrl(origin, path: "/api/avatar", slug: slug, rev: rev)
}

public func backdropUrl(_ origin: String, slug: String, rev: Int = 0) -> String {
  blobUrl(origin, path: "/api/backdrop", slug: slug, rev: rev)
}

public func themeUrl(_ origin: String, slug: String) -> String {
  "\(httpOrigin(origin))/api/theme?slug=\(slug)"
}
