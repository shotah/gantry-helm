import Foundation

/// One Simulator capture. `make shot` launches DEBUG Helm with `-shot <file>`.
/// CarPlay rows stay out: there is no conversation screen to photograph.
public struct DocShot: Equatable {
  public var file: String
  public var sample: String
  public var theme: String
  public var open: String

  public init(file: String, sample: String, theme: String = "boom", open: String = "") {
    self.file = file
    self.sample = sample
    self.theme = theme
    self.open = open
  }
}

public let docShots: [DocShot] = [
  DocShot(file: "phone-unsigned", sample: "unsigned"),
  DocShot(file: "phone-empty", sample: "empty"),
  DocShot(file: "phone-thread", sample: "thread"),
  DocShot(file: "phone-stream", sample: "stream"),
  DocShot(file: "phone-photo", sample: "photo"),
  DocShot(file: "phone-down", sample: "down"),
  DocShot(file: "phone-settings", sample: "empty", open: "settings"),
  DocShot(file: "phone-emoji", sample: "thread", open: "emoji"),
  DocShot(file: "phone-attach", sample: "thread", open: "attach"),
  DocShot(file: "phone-draft", sample: "thread", open: "draft"),
  DocShot(file: "phone-thread-lamp", sample: "thread", theme: "lamp"),
  DocShot(file: "phone-thread-paper", sample: "thread", theme: "paper"),
]

public func docShot(_ raw: String?) -> DocShot? {
  let id = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
  return docShots.first { $0.file == id }
}

/// `-shot phone-thread` or `--shot=phone-thread`. Unknown names are ignored.
public func launchDocShot(_ args: [String]) -> DocShot? {
  if let i = args.firstIndex(of: "-shot"), args.indices.contains(i + 1) {
    return docShot(args[i + 1])
  }
  for arg in args where arg.hasPrefix("--shot=") {
    return docShot(String(arg.dropFirst("--shot=".count)))
  }
  return nil
}
