import Foundation
import Mailbox

enum HelmGoogle {
  static func signIn(
    webClientId: String,
    origin: String,
    completion: @escaping (Result<NativeSession, Error>) -> Void
  ) {
    #if canImport(GoogleSignIn)
    // Wired when the Xcode target adds GoogleSignIn-iOS.
    // nonce: GET /api/auth/nonce, else mintNonce(); POST /api/auth/token.
    completion(.failure(GoogleNeedPackage()))
    #else
    completion(.failure(GoogleNeedPackage()))
    #endif
  }

  static func exchange(origin: String, idToken: String, nonce: String) throws -> NativeSession {
    let http = URLSessionTransport()
    return try AuthApi(transport: http).token(origin: origin, idToken: idToken, nonce: nonce)
  }

  static func fetchNonce(origin: String) -> String {
    let http = URLSessionTransport()
    return AuthApi(transport: http).nonce(origin: origin) ?? mintNonce()
  }
}

struct GoogleNeedPackage: Error, LocalizedError {
  var errorDescription: String? {
    "Add the GoogleSignIn-iOS package in Xcode, plus an iOS OAuth client for com.gantree.helm."
  }
}

struct URLSessionTransport: HTTPTransport {
  func perform(_ request: URLRequest) throws -> HTTPResult {
    var req = request
    req.httpShouldHandleCookies = false
    let sem = DispatchSemaphore(value: 0)
    var box: (Data?, URLResponse?, Error?)?
    URLSession.shared.dataTask(with: req) { data, res, err in
      box = (data, res, err)
      sem.signal()
    }.resume()
    sem.wait()
    if let err = box?.2 {
      throw err
    }
    let data = box?.0 ?? Data()
    let status = (box?.1 as? HTTPURLResponse)?.statusCode ?? 0
    var headers: [String: String] = [:]
    (box?.1 as? HTTPURLResponse)?.allHeaderFields.forEach { k, v in
      if let k = k as? String {
        headers[k] = String(describing: v)
      }
    }
    return HTTPResult(status: status, body: data, headers: headers)
  }
}
