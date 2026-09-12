import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Mailbox

final class AvatarApiTests: XCTestCase {
  func testBlobCacheKeyIsStablePerRoomAndPath() {
    let a = blobCacheKey(origin: "https://ex.workers.dev/", slug: "kit", path: "/api/avatar")
    let b = blobCacheKey(origin: "https://ex.workers.dev", slug: "kit", path: "/api/avatar")
    XCTAssertEqual(a, b)
    XCTAssertTrue(a.hasPrefix("api-avatar-"))
    XCTAssertEqual(16, a.split(separator: "-").last?.count)
    XCTAssertNotEqual(
      a,
      blobCacheKey(origin: "https://ex.workers.dev/", slug: "kit", path: "/api/backdrop")
    )
    XCTAssertNotEqual(
      a,
      blobCacheKey(origin: "https://ex.workers.dev/", slug: "ada", path: "/api/avatar")
    )
  }

  func testFetchReturnsBytesAndSendsBearer() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: fakeJpeg())]
    let got = AvatarApi(transport: http).fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 3)
    XCTAssertEqual(fakeJpeg(), got)
    XCTAssertEqual("/api/avatar", http.requests[0].url?.path)
    XCTAssertEqual("slug=kit&v=3", http.requests[0].url?.query)
    XCTAssertEqual("Bearer jwe", http.requests[0].value(forHTTPHeaderField: "Authorization"))
  }

  func testFetchBackdropUsesTheBackdropPath() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: fakeJpeg())]
    let got = AvatarApi(transport: http).fetch(
      origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 4, path: "/api/backdrop"
    )
    XCTAssertEqual(fakeJpeg(), got)
    XCTAssertEqual("/api/backdrop", http.requests[0].url?.path)
    XCTAssertEqual("slug=kit&v=4", http.requests[0].url?.query)
  }

  func testFetchMissIsNull() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 404, body: Data())]
    XCTAssertNil(AvatarApi(transport: http).fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "", rev: 0))
    XCTAssertNil(http.requests[0].value(forHTTPHeaderField: "Authorization"))
  }

  func testFetchKeepsTheLastFaceAndItsRevOnDiskAndCachedReadsItBack() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("helm-blob-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let cache = BlobCache(dir: dir)
    let http = MockHTTP()
    let jpeg = fakeJpeg()
    http.queue = [
      HTTPResult(status: 200, body: jpeg, headers: ["X-Pendant-Rev": "7", "ETag": "\"7\""]),
    ]
    let api = AvatarApi(transport: http, cache: cache)
    XCTAssertNil(api.cached(origin: "http://mailbox.test/", slug: "kit"))
    XCTAssertEqual(jpeg, api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 1))
    XCTAssertNil(http.requests[0].value(forHTTPHeaderField: "If-None-Match"))
    XCTAssertEqual(jpeg, api.cached(origin: "http://mailbox.test/", slug: "kit"))
    let stored = cache.read(blobCacheKey(origin: "http://mailbox.test/", slug: "kit", path: "/api/avatar"))!
    XCTAssertEqual(jpeg, stored.bytes)
    XCTAssertEqual(7, stored.rev)
    XCTAssertNil(api.cached(origin: "http://mailbox.test/", slug: "kit", path: "/api/backdrop"))
  }

  func testFetchRevalidatesWithIfNoneMatchAndA304KeepsTheCachedBytes() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("helm-blob-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let cache = BlobCache(dir: dir)
    let http = MockHTTP()
    let jpeg = fakeJpeg()
    let next = fakeJpeg(200)
    http.queue = [
      HTTPResult(status: 200, body: jpeg, headers: ["X-Pendant-Rev": "7"]),
      HTTPResult(status: 304, body: Data(), headers: ["X-Pendant-Rev": "7", "ETag": "\"7\""]),
      HTTPResult(status: 200, body: next, headers: ["X-Pendant-Rev": "8"]),
      HTTPResult(status: 304, body: Data()),
    ]
    let api = AvatarApi(transport: http, cache: cache)
    XCTAssertEqual(jpeg, api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 0))
    XCTAssertEqual(jpeg, api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 0))
    XCTAssertEqual("\"7\"", http.requests[1].value(forHTTPHeaderField: "If-None-Match"))
    XCTAssertEqual(7, cache.rev(blobCacheKey(origin: "http://mailbox.test/", slug: "kit", path: "/api/avatar")))
    XCTAssertEqual(next, api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 8))
    XCTAssertEqual("\"7\"", http.requests[2].value(forHTTPHeaderField: "If-None-Match"))
    XCTAssertEqual(next, api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 8))
    XCTAssertEqual("\"8\"", http.requests[3].value(forHTTPHeaderField: "If-None-Match"))
  }

  func testABlobWithoutARevIsKeptButNeverRevalidated() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("helm-blob-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let http = MockHTTP()
    let jpeg = fakeJpeg()
    http.queue = [
      HTTPResult(status: 200, body: jpeg),
      HTTPResult(status: 200, body: jpeg),
    ]
    let api = AvatarApi(transport: http, cache: BlobCache(dir: dir))
    XCTAssertEqual(jpeg, api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 0))
    XCTAssertEqual(jpeg, api.cached(origin: "http://mailbox.test/", slug: "kit"))
    _ = api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 0)
    XCTAssertNil(http.requests[1].value(forHTTPHeaderField: "If-None-Match"))
  }

  func testFetchFailureAnswersWithTheCachedBytesNotBlank() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("helm-blob-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let cache = BlobCache(dir: dir)
    let http = MockHTTP()
    let jpeg = fakeJpeg()
    http.queue = [
      HTTPResult(status: 200, body: jpeg),
      HTTPResult(status: 503, body: Data()),
      HTTPResult(status: 401, body: Data()),
    ]
    let api = AvatarApi(transport: http, cache: cache)
    _ = api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 1)
    XCTAssertEqual(jpeg, api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 1))
    XCTAssertEqual(jpeg, api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "expired", rev: 1))
    http.throwNext = true
    XCTAssertEqual(jpeg, api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 1))
  }

  func testFetchMissForgetsTheCachedBytes() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("helm-blob-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let http = MockHTTP()
    http.queue = [
      HTTPResult(status: 200, body: fakeJpeg()),
      HTTPResult(status: 404, body: Data()),
    ]
    let api = AvatarApi(transport: http, cache: BlobCache(dir: dir))
    XCTAssertNotNil(api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 1, path: "/api/backdrop"))
    XCTAssertNil(api.fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 0, path: "/api/backdrop"))
    XCTAssertNil(api.cached(origin: "http://mailbox.test/", slug: "kit", path: "/api/backdrop"))
  }

  func testFailureWithoutACacheIsStillNull() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 503, body: Data())]
    XCTAssertNil(AvatarApi(transport: http).fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", rev: 0))
  }

  func testUploadRejectsNonJpeg() {
    let http = MockHTTP()
    let got = AvatarApi(transport: http).upload(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", jpeg: Data([1, 2, 3]))
    XCTAssertEqual(AvatarUpload.err(error: "image too small"), got)
    XCTAssertEqual(0, http.requests.count)
  }

  func testUploadPostsMultipartAndReturnsRev() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data(#"{"ok":true,"rev":9}"#.utf8))]
    let got = AvatarApi(transport: http).upload(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe", jpeg: fakeJpeg())
    XCTAssertEqual(AvatarUpload.ok(rev: 9), got)
    XCTAssertEqual("POST", http.requests[0].httpMethod)
    XCTAssertTrue(http.requests[0].value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
    XCTAssertEqual("Bearer jwe", http.requests[0].value(forHTTPHeaderField: "Authorization"))
  }

  func testUploadSurfacesDetail() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 400, body: Data(#"{"detail":"need a JPEG"}"#.utf8))]
    XCTAssertEqual(
      AvatarUpload.err(error: "need a JPEG"),
      AvatarApi(transport: http).upload(origin: "http://mailbox.test/", slug: "kit", bearer: "", jpeg: fakeJpeg())
    )
  }

  func testUploadNeedsAPositiveRev() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data(#"{"ok":true,"rev":0}"#.utf8))]
    if case .err = AvatarApi(transport: http).upload(
      origin: "http://mailbox.test/", slug: "kit", bearer: "", jpeg: fakeJpeg()
    ) {
    } else {
      XCTFail("expected err")
    }
  }

  func testParseAvatarUploadReadsOkAndDetail() {
    XCTAssertEqual(AvatarUpload.ok(rev: 3), parseAvatarUpload(status: 200, raw: #"{"ok":true,"rev":3}"#))
    XCTAssertEqual(AvatarUpload.err(error: "nope"), parseAvatarUpload(status: 400, raw: #"{"error":"nope"}"#))
    XCTAssertEqual(AvatarUpload.err(error: "upload failed"), parseAvatarUpload(status: 200, raw: "nope"))
  }
}
