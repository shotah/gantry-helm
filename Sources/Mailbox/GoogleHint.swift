public func googleSignInHint(className: String, message: String?, causeLines: [String] = []) -> String {
  let msg = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  let summary: String
  if msg.contains("28444") || msg.lowercased().contains("developer console") {
    summary =
      "GCP isn’t set up for this IPA. Add an iOS OAuth client: bundle com.gantree.helm."
  } else if className.lowercased().contains("cancel") {
    summary =
      "Google closed the sheet after the account. That is often a URL-scheme / client-id mismatch, not you hitting Cancel."
  } else if className.lowercased().contains("nocredential") || msg.lowercased().contains("keychain") {
    summary =
      "No Google account, or this app’s bundle isn’t an iOS OAuth client for com.gantree.helm."
  } else if !msg.isEmpty {
    summary = msg
  } else {
    summary = "Google sign-in failed."
  }
  var trail: [String] = []
  trail.append(className.split(separator: ".").last.map(String.init) ?? className)
  if !msg.isEmpty {
    trail.append(msg)
  }
  trail.append(
    contentsOf: causeLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
  )
  var seen = Set<String>()
  let unique = trail.filter { seen.insert($0).inserted }
  return unique.isEmpty ? summary : summary + "\n" + unique.joined(separator: " → ")
}

public func googleSignInHint(_ err: Error) -> String {
  var causes: [String] = []
  let ns = err as NSError
  if let under = ns.userInfo[NSUnderlyingErrorKey] as? Error {
    let m = under.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    causes.append(m.isEmpty ? String(describing: type(of: under)) : "\(type(of: under)): \(m)")
  }
  return googleSignInHint(
    className: String(describing: type(of: err)),
    message: err.localizedDescription,
    causeLines: causes
  )
}
