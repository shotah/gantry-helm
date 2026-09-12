import XCTest
@testable import Mailbox

final class MockHTTP: HTTPTransport {
  var queue: [HTTPResult] = []
  var requests: [URLRequest] = []

  func perform(_ request: URLRequest) throws -> HTTPResult {
    requests.append(request)
    return queue.removeFirst()
  }
}

final class AuthThemeJpegTests: XCTestCase {
  func testConfigReadsModeAndGoogle() throws {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data(#"{"mode":"google","google":true}"#.utf8))]
    let api = AuthApi(transport: http)
    let got = try api.config(origin: "http://mailbox.test/")
    XCTAssertEqual("google", got.mode)
    XCTAssertEqual(true, got.google)
    XCTAssertEqual("/api/auth/config", http.requests[0].url?.path)
  }

  func testMeReadsCranesAndSkipsBlanks() throws {
    let http = MockHTTP()
    http.queue = [
      HTTPResult(
        status: 200,
        body: Data(#"{"sub":"u1","email":"ada@example.com","cranes":["kit","", "dock","Nope!"]}"#.utf8)
      ),
    ]
    let api = AuthApi(transport: http)
    let got = try api.me(origin: "http://mailbox.test/", token: "jwe")
    XCTAssertEqual("u1", got.sub)
    XCTAssertEqual("ada@example.com", got.email)
    XCTAssertEqual(["kit", "dock"], got.cranes)
    XCTAssertEqual("Bearer jwe", http.requests[0].value(forHTTPHeaderField: "Authorization"))
  }

  func testConfigIgnoresAdditiveKeys() throws {
    let http = MockHTTP()
    http.queue = [
      HTTPResult(status: 200, body: Data(#"{"mode":"google","google":true,"version":"0.4.0","dev":true}"#.utf8)),
    ]
    let api = AuthApi(transport: http)
    let got = try api.config(origin: "http://mailbox.test/")
    XCTAssertEqual("google", got.mode)
    XCTAssertEqual(true, got.google)
    XCTAssertNil(http.requests[0].value(forHTTPHeaderField: "Cookie"))
  }

  func testNonceReadsTheValue() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data(#"{"nonce":"nce-1"}"#.utf8))]
    let api = AuthApi(transport: http)
    XCTAssertEqual("nce-1", api.nonce(origin: "http://mailbox.test/"))
    XCTAssertEqual("/api/auth/nonce", http.requests[0].url?.path)
    XCTAssertEqual("GET", http.requests[0].httpMethod)
    XCTAssertNil(http.requests[0].value(forHTTPHeaderField: "Cookie"))
  }

  func testNonceMissingRouteReturnsNil() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 404, body: Data(#"{"error":"not found"}"#.utf8))]
    XCTAssertNil(AuthApi(transport: http).nonce(origin: "http://mailbox.test/"))
  }

  func testNonceEmptyBodyReturnsNil() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data("{}".utf8))]
    XCTAssertNil(AuthApi(transport: http).nonce(origin: "http://mailbox.test/"))
  }

  func testConfigDefaultsWhenTheBodyIsEmpty() throws {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data("{}".utf8))]
    let got = try AuthApi(transport: http).config(origin: "http://mailbox.test/")
    XCTAssertNil(got.mode)
    XCTAssertEqual(false, got.google)
  }

  func testMeWithoutCranesIsEmpty() throws {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data(#"{"sub":"u1"}"#.utf8))]
    let got = try AuthApi(transport: http).me(origin: "http://mailbox.test/", token: "jwe")
    XCTAssertNil(got.email)
    XCTAssertEqual([], got.cranes)
  }

  func testTokenPostsIdToken() throws {
    let http = MockHTTP()
    http.queue = [
      HTTPResult(status: 200, body: Data(#"{"token":"jwe","sub":"u1","email":"ada@example.com","exp":9}"#.utf8)),
    ]
    let got = try AuthApi(transport: http).token(origin: "http://mailbox.test/", idToken: "id", nonce: "nonce")
    XCTAssertEqual("jwe", got.token)
    XCTAssertEqual("u1", got.sub)
    XCTAssertEqual(9, got.exp)
    XCTAssertEqual("POST", http.requests[0].httpMethod)
    XCTAssertNil(http.requests[0].value(forHTTPHeaderField: "Cookie"))
    let body = String(data: http.requests[0].httpBody ?? Data(), encoding: .utf8) ?? ""
    XCTAssertTrue(body.contains("id_token"))
  }

  func testFailedStatusIsAuthError() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 401, body: Data(#"{"error":"nope"}"#.utf8))]
    do {
      _ = try AuthApi(transport: http).config(origin: "http://mailbox.test/")
      XCTFail("expected AuthError")
    } catch let err as AuthError {
      XCTAssertEqual(401, err.code)
      XCTAssertTrue(err.body.contains("nope"))
    } catch {
      XCTFail("wrong error \(error)")
    }
  }

  func testMintNonceIsUrlSafe() {
    let n = mintNonce()
    XCTAssertFalse(n.contains("+"))
    XCTAssertFalse(n.contains("/"))
    XCTAssertFalse(n.contains("="))
    XCTAssertTrue(n.count >= 20)
  }

  func testRoomThemeFromStateReadsTheIdAndTreatsNullAsCleared() {
    XCTAssertEqual("tide", roomThemeFromState(#"{"theme":"tide","themes":[]}"#))
    XCTAssertEqual("", roomThemeFromState(#"{"theme":null}"#))
    XCTAssertEqual("", roomThemeFromState(#"{"theme":"nope"}"#))
    XCTAssertEqual("", roomThemeFromState("nope"))
  }

  func testFetchReturnsTheRoomIdAndSendsBearer() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data(#"{"theme":"noir","themes":[]}"#.utf8))]
    XCTAssertEqual("noir", ThemeApi(transport: http).fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe"))
    XCTAssertEqual("/api/theme", http.requests[0].url?.path)
    XCTAssertEqual("slug=kit", http.requests[0].url?.query)
    XCTAssertEqual("Bearer jwe", http.requests[0].value(forHTTPHeaderField: "Authorization"))
  }

  func testFetchMissOrJunkIsClearedNotANetworkFail() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 200, body: Data(#"{"theme":null}"#.utf8))]
    XCTAssertEqual("", ThemeApi(transport: http).fetch(origin: "http://mailbox.test/", slug: "kit", bearer: ""))
    XCTAssertNil(http.requests[0].value(forHTTPHeaderField: "Authorization"))
  }

  func testFetchHttpErrorIsNilSoALiveNoticeIsKept() {
    let http = MockHTTP()
    http.queue = [HTTPResult(status: 503, body: Data())]
    XCTAssertNil(ThemeApi(transport: http).fetch(origin: "http://mailbox.test/", slug: "kit", bearer: "jwe"))
  }

  func testRejectsTinyHugeAndNonJpeg() {
    XCTAssertFalse(acceptJpeg(fakeJpeg(8)).ok)
    if case .err(let detail) = acceptJpeg(fakeJpeg(8)) {
      XCTAssertEqual("image too small", detail)
    }
    if case .err(let detail) = acceptJpeg(Data(count: avatarMaxBytes + 1)) {
      XCTAssertEqual("image too large (max 5MB)", detail)
    }
    var png = Data(count: 64)
    png[0] = 0x89
    png[1] = 0x50
    XCTAssertFalse(acceptJpeg(png).ok)
    XCTAssertTrue(acceptJpeg(fakeJpeg()).ok)
  }

  func testPassthroughKeepsASmallJpeg() {
    XCTAssertTrue(shouldPassthroughJpeg(type: "image/jpeg", size: 100, width: 64, height: 64))
    XCTAssertFalse(shouldPassthroughJpeg(type: "image/png", size: 100, width: 64, height: 64))
    XCTAssertFalse(shouldPassthroughJpeg(type: "image/jpeg", size: 100, width: 2000, height: 64))
    XCTAssertFalse(
      shouldPassthroughJpeg(type: "image/jpeg", size: 2_000_000, width: 64, height: 64, maxBytes: 1_500_000)
    )
  }
}

func fakeJpeg(_ n: Int = 128) -> Data {
  var b = Data(count: n)
  b[0] = 0xFF
  b[1] = 0xD8
  b[2] = 0xFF
  b[n - 1] = 0xD9
  return b
}
