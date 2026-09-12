import Foundation

/// Why the phone socket must not open yet. Null means go ahead.
public func mailboxConnectError(
  slug: String,
  bearer: String,
  sessionExpired: Bool = false
) -> String? {
  if parseSlug(slug) == nil {
    return "Talking to needs a crane slug like kit."
  }
  if sessionExpired {
    return "Google session expired — sign in again."
  }
  if bearer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    return "No Google session or phone secret yet — the mailbox socket cannot open."
  }
  return nil
}

/// JWT `exp` is unix seconds. Zero means unknown — do not lock the phone out.
public func sessionExpired(expEpochSec: Int64, nowEpochSec: Int64) -> Bool {
  expEpochSec > 0 && nowEpochSec >= expEpochSec
}

/// Prefer the Google session; never fall back to the spike after it expires.
public func liveBearer(session: String, sessionExp: Int64, spike: String, nowEpochSec: Int64) -> String {
  if !session.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    return sessionExpired(expEpochSec: sessionExp, nowEpochSec: nowEpochSec) ? "" : session
  }
  return spike
}

/**
 Simulator / loopback may persist the lab secret. A debug build on a real
 phone must not write it to disk. Google session: never keep the spike.
 */
public func persistSpikeAllowed(origin: String, hasGoogleSession: Bool, debugBuild: Bool) -> Bool {
  if hasGoogleSession {
    return false
  }
  if !debugBuild {
    return true
  }
  return loopbackMailboxHost(origin)
}

public func loopbackMailboxHost(_ origin: String) -> Bool {
  let raw = normalizeMailboxOrigin(origin)
  if raw.isEmpty {
    return false
  }
  guard let url = URL(string: raw), let host = url.host?.lowercased() else {
    return false
  }
  return host == "10.0.2.2" || host == "localhost" || host == "127.0.0.1"
}

public func mailboxSocketHint(code: Int?, detail: String?) -> String {
  let bit = (detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
    ? "retrying"
    : detail!.trimmingCharacters(in: .whitespacesAndNewlines)
  switch code {
  case 401, 403:
    return "Mailbox refused the socket (HTTP \(code!)). Google worked, but this crane’s room list may not include you."
  case 404:
    return "Mailbox has no socket for this crane name (HTTP 404)."
  case nil:
    return "Mailbox socket down — \(String(bit.prefix(160)))"
  default:
    return "Mailbox socket down (HTTP \(code!)) — \(String(bit.prefix(120)))"
  }
}

public func mailboxSignedInHint(email: String, cranes: [String]) -> String {
  let who = email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "you" : email
  if cranes.isEmpty {
    return "Google worked (\(who)), but this mailbox listed no cranes for you. The socket stays offline until you’re on the room list."
  }
  return "Signed in as \(who)"
}

/// Email + Google sub, what the yard admin pastes. Pendant copies the same two lines.
public func allowlistCopy(email: String, sub: String) -> String {
  [email, sub]
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { !$0.isEmpty }
    .joined(separator: "\n")
}

public func mailboxTimeoutHint() -> String {
  "Mailbox timed out — iOS ended the background socket. Open Helm to listen again."
}

/// No second handshake within this of the last open — a resume right after launch is not a gap.
public let sweepMinGapMs: Int64 = 10_000
/// While a thread is on some screen, sweep the mailbox this often.
public let sweepEveryMs: Int64 = 2 * 60_000

/**
 A quiet sweep is worth its handshake only while someone is looking at the
 thread. The mailbox does not push what another mouth of yours sent; a
 connect flush is how it comes over, so we take one on a slow tick.
 */
public func watchingThread(phoneResumed: Bool, carThreadVisible: Bool) -> Bool {
  phoneResumed || carThreadVisible
}

/// HTTP 401/403/404 are terminal; keep retrying transport failures.
public func mailboxShouldRetry(_ httpCode: Int?) -> Bool {
  switch httpCode {
  case 401, 403, 404, 4401:
    return false
  default:
    return true
  }
}

/// Handshake 401: this JWE is no good. Do not drop on 403 (wrong room, same human).
public func mailboxHttpDropsSession(_ httpCode: Int?) -> Bool {
  httpCode == 401
}

/**
 Mailbox close `4401` is "this credential may not talk" — yanked `sub`,
 expired session on the next frame, later an `iat` floor. Drop the JWE.
 */
public let mailboxCloseUnauthorized = 4401

public func mailboxCloseDropsAuth(_ code: Int) -> Bool {
  code == mailboxCloseUnauthorized
}

public func mailboxAuthLostHint() -> String {
  "Mailbox closed the session — sign in again."
}

/// 2s, 4s, 8s, 16s, 32s, then cap at 60s.
public func mailboxRetryDelayMs(_ attempt: Int) -> Int64 {
  let shift = min(max(attempt, 0), 5)
  return min(2_000 << shift, 60_000)
}
