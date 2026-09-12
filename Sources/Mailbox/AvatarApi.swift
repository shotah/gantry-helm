import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AvatarUpload: Equatable {
  case ok(rev: Int)
  case err(error: String)
}

/// One GET of a room blob. Same = 304 for the rev we hold; Missing = none; Failed = unknown.
enum Fetched {
  case got(CachedBlob)
  case same
  case missing
  case failed
}

/**
 Conditional GET for `/api/avatar` or `/api/backdrop`. A 304 or a failed
 request keeps the cached bytes; a 404 forgets them.
 */
public final class AvatarApi {
  private let transport: HTTPTransport
  private let cache: BlobCache?

  public init(transport: HTTPTransport, cache: BlobCache? = nil) {
    self.transport = transport
    self.cache = cache
  }

  /// What [fetch] last kept for this room — paint it before the mailbox answers.
  public func cached(origin: String, slug: String, path: String = "/api/avatar") -> Data? {
    cache?.read(blobCacheKey(origin: origin, slug: slug, path: path))?.bytes
  }

  /**
   Current bytes, or nil when the room has none. Sends `If-None-Match`
   for the rev on disk. Offline / 5xx / expired session keep the last
   face; a 404 forgets it.
   */
  public func fetch(
    origin: String,
    slug: String,
    bearer: String,
    rev: Int,
    path: String = "/api/avatar"
  ) -> Data? {
    let key = blobCacheKey(origin: origin, slug: slug, path: path)
    let held = cache?.rev(key) ?? 0
    guard let url = URL(string: blobUrl(origin, path: path, slug: slug, rev: rev)) else {
      return cache?.read(key)?.bytes
    }
    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    if !bearer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }
    if held > 0 {
      req.setValue(blobEtag(held), forHTTPHeaderField: "If-None-Match")
    }
    let got: Fetched
    do {
      let res = try transport.perform(req)
      if res.status == 304 && held > 0 {
        got = .same
      } else if res.status >= 200 && res.status < 300 {
        if res.body.isEmpty {
          got = .missing
        } else {
          got = .got(
            CachedBlob(
              rev: blobRev(httpHeader(res.headers, "X-Pendant-Rev"), etag: httpHeader(res.headers, "ETag")),
              bytes: res.body
            )
          )
        }
      } else if res.status == 404 {
        got = .missing
      } else {
        got = .failed
      }
    } catch {
      got = .failed
    }
    switch got {
    case .got(let blob):
      cache?.write(key, blob)
      return blob.bytes
    case .missing:
      cache?.write(key, nil)
      return nil
    case .same, .failed:
      return cache?.read(key)?.bytes
    }
  }

  public func upload(origin: String, slug: String, bearer: String, jpeg: Data) -> AvatarUpload {
    if case .err(let detail) = acceptJpeg(jpeg) {
      return .err(error: detail)
    }
    guard let url = URL(string: avatarUrl(origin, slug: slug)) else {
      return .err(error: "upload failed")
    }
    let boundary = "helm-\(UUID().uuidString)"
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    if !bearer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }
    req.httpBody = multipartJpeg(jpeg, boundary: boundary)
    do {
      let res = try transport.perform(req)
      return parseAvatarUpload(status: res.status, raw: String(data: res.body, encoding: .utf8) ?? "")
    } catch {
      return .err(error: "upload failed")
    }
  }
}

public func parseAvatarUpload(status: Int, raw: String) -> AvatarUpload {
  let o = JSON.object(raw) ?? [:]
  let rev = jsonWholeNumber(o["rev"]) ?? -1
  if status >= 200 && status < 300 && JSON.bool(o, "ok") && rev > 0 {
    return .ok(rev: Int(rev))
  }
  let err = JSON.string(o, "detail") ?? JSON.string(o, "error") ?? "upload failed"
  return .err(error: err)
}

func httpHeader(_ headers: [String: String], _ name: String) -> String? {
  let want = name.lowercased()
  for (k, v) in headers where k.lowercased() == want {
    return v
  }
  return nil
}

func multipartJpeg(_ jpeg: Data, boundary: String) -> Data {
  var body = Data()
  func line(_ s: String) {
    body.append(Data(s.utf8))
  }
  line("--\(boundary)\r\n")
  line("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n")
  line("Content-Type: image/jpeg\r\n\r\n")
  body.append(jpeg)
  line("\r\n--\(boundary)--\r\n")
  return body
}
