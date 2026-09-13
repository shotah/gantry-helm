import Foundation
import Mailbox
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(UIKit)
import UIKit
#endif

enum HelmGoogle {
  @discardableResult
  static func handle(_ url: URL) -> Bool {
    #if canImport(GoogleSignIn)
    GIDSignIn.sharedInstance.handle(url)
    #else
    false
    #endif
  }

  static func signIn(
    webClientId: String,
    origin: String,
    completion: @escaping (Result<NativeSession, Error>) -> Void
  ) {
    #if canImport(GoogleSignIn) && canImport(UIKit)
    let ios = HelmConfig.googleIosClientId.trimmingCharacters(in: .whitespacesAndNewlines)
    if ios.isEmpty {
      completion(.failure(GoogleNeedClient()))
      return
    }
    guard let vc = helmPresenter() else {
      completion(.failure(GoogleNeedPresenter()))
      return
    }
    let nonce = fetchNonce(origin: origin)
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(
      clientID: ios,
      serverClientID: webClientId
    )
    DispatchQueue.main.async {
      GIDSignIn.sharedInstance.signIn(
        withPresenting: vc,
        hint: nil,
        additionalScopes: nil,
        nonce: nonce
      ) { result, error in
        if let error {
          completion(.failure(error))
          return
        }
        guard let token = result?.user.idToken?.tokenString else {
          completion(.failure(GoogleNeedPackage()))
          return
        }
        do {
          completion(.success(try exchange(origin: origin, idToken: token, nonce: nonce)))
        } catch {
          completion(.failure(error))
        }
      }
    }
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

  static func fetchMe(origin: String, token: String) -> Me? {
    try? AuthApi(transport: URLSessionTransport()).me(origin: origin, token: token)
  }
}

#if canImport(UIKit)
func helmPresenter() -> UIViewController? {
  let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
  let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.flatMap(\.windows).first
  var vc = window?.rootViewController
  while let shown = vc?.presentedViewController {
    vc = shown
  }
  return vc
}
#endif

struct GoogleNeedPackage: Error, LocalizedError {
  var errorDescription: String? {
    "Add the GoogleSignIn-iOS package in Xcode, plus an iOS OAuth client for com.gantree.helm."
  }
}

struct GoogleNeedClient: Error, LocalizedError {
  var errorDescription: String? {
    "This build has no iOS OAuth client. Bake HELM_GOOGLE_IOS_CLIENT_ID."
  }
}

struct GoogleNeedPresenter: Error, LocalizedError {
  var errorDescription: String? {
    "Google Sign-In needs a window to present from. Open Helm and try again."
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
