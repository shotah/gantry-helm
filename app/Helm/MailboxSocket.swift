import Foundation
import Mailbox

/// URLSession WebSocket. Bearer only — never a `pendant_session` cookie.
final class MailboxSocket: NSObject, URLSessionWebSocketDelegate {
  private let onFrame: (WireFrame) -> Void
  private let onState: (Bool) -> Void
  private let onAuthLost: () -> Void
  private var task: URLSessionWebSocketTask?
  private var session: URLSession?
  private var stopped = true
  private var attempt = 0
  private var openedAt: Int64 = 0
  private var room: (origin: String, slug: String, bearer: String)?
  private let seen = SeenCursor()
  private var retrying = false
  private var authLost = false
  private var generation = 0

  init(
    onFrame: @escaping (WireFrame) -> Void,
    onState: @escaping (Bool) -> Void,
    onAuthLost: @escaping () -> Void
  ) {
    self.onFrame = onFrame
    self.onState = onState
    self.onAuthLost = onAuthLost
  }

  func remember(id: String, seq: Int?) {
    seen.remember(id: id, seq: seq)
  }

  func start(origin: String, slug: String, bearer: String) {
    room = (origin, slug, bearer)
    stopped = false
    authLost = false
    attempt = 0
    connect(origin: origin, slug: slug, bearer: bearer)
  }

  func stop() {
    stopped = true
    generation += 1
    task?.cancel(with: .goingAway, reason: nil)
    task = nil
    onState(false)
  }

  @discardableResult
  func send(_ frame: WireFrame) -> Bool {
    guard let task else {
      return false
    }
    task.send(.string(encodeFrame(frame))) { _ in }
    return true
  }

  @discardableResult
  func sweep(now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> Bool {
    guard let room, !stopped, now - openedAt >= sweepMinGapMs else {
      return false
    }
    connect(origin: room.origin, slug: room.slug, bearer: room.bearer)
    return true
  }

  private func connect(origin: String, slug: String, bearer: String) {
    if stopped {
      return
    }
    generation += 1
    let gen = generation
    task?.cancel(with: .goingAway, reason: nil)
    let url = URL(string: mailboxUrl(origin, slug: slug))!
    var req = URLRequest(url: url, timeoutInterval: 15)
    req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    let config = URLSessionConfiguration.ephemeral
    config.httpCookieAcceptPolicy = .never
    config.httpShouldSetCookies = false
    config.timeoutIntervalForRequest = 15
    let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    self.session = session
    let task = session.webSocketTask(with: req)
    self.task = task
    task.resume()
    listen(gen)
    // URLSession does not give onOpen until the first message on some versions;
    // mark live when the handshake HTTP is 101 via delegate.
    _ = gen
  }

  private func listen(_ gen: Int) {
    task?.receive { [weak self] result in
      guard let self, gen == self.generation, !self.stopped else {
        return
      }
      switch result {
      case .failure:
        break
      case .success(let msg):
        switch msg {
        case .string(let text):
          self.handle(text)
        case .data(let data):
          if let text = String(data: data, encoding: .utf8) {
            self.handle(text)
          }
        @unknown default:
          break
        }
        self.listen(gen)
      }
    }
  }

  private func handle(_ text: String) {
    if text == "ping" {
      task?.send(.string("pong")) { _ in }
      return
    }
    guard let frame = parseFrame(text) else {
      return
    }
    seen.note(frame: frame)
    onFrame(frame)
  }

  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol proto: String?
  ) {
    if stopped {
      webSocketTask.cancel(with: .goingAway, reason: nil)
      return
    }
    attempt = 0
    openedAt = Int64(Date().timeIntervalSince1970 * 1000)
    if let since = seen.since() {
      webSocketTask.send(.string(encodeFrame(ackSince(since)))) { _ in }
    }
    onState(true)
  }

  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
    reason: Data?
  ) {
    if mailboxCloseDropsAuth(Int(closeCode.rawValue)) {
      dropAuth()
      return
    }
    onState(false)
    retry(httpCode: nil)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if stopped {
      return
    }
    let code = (task.response as? HTTPURLResponse)?.statusCode
    onState(false)
    if mailboxHttpDropsSession(code) {
      dropAuth()
      return
    }
    retry(httpCode: code)
  }

  private func dropAuth() {
    if authLost {
      return
    }
    authLost = true
    stopped = true
    onState(false)
    onAuthLost()
  }

  private func retry(httpCode: Int?) {
    if stopped {
      return
    }
    if !mailboxShouldRetry(httpCode) {
      stopped = true
      return
    }
    if retrying {
      return
    }
    retrying = true
    let delay = mailboxRetryDelayMs(attempt)
    attempt += 1
    let room = self.room
    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(delay))) { [weak self] in
      guard let self else {
        return
      }
      self.retrying = false
      if let room, !self.stopped {
        self.connect(origin: room.origin, slug: room.slug, bearer: room.bearer)
      }
    }
  }
}
