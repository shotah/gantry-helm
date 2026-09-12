import Foundation

public let commandsMax = 32
public let commandNameMax = 32
public let commandHintMax = 256

private let nameRegex = try! NSRegularExpression(pattern: "^[a-z][a-z0-9_]{0,31}$")

public struct SlashCommand: Equatable {
  public var name: String
  public var hint: String
  public var args: Bool

  public init(name: String, hint: String, args: Bool = false) {
    self.name = name
    self.hint = hint
    self.args = args
  }
}

public func slashToken(_ text: String) -> String? {
  if !text.hasPrefix("/") || text.contains(where: { $0.isWhitespace }) {
    return nil
  }
  return String(text.dropFirst()).lowercased()
}

public func matchSlash(_ text: String, catalog: [SlashCommand]) -> [SlashCommand] {
  guard let token = slashToken(text) else {
    return []
  }
  return catalog.filter { $0.name.hasPrefix(token) }
}

public func slashInsert(_ cmd: SlashCommand) -> String {
  cmd.args ? "/\(cmd.name) " : "/\(cmd.name)"
}

public func parseCommands(_ raw: Any?) -> [SlashCommand] {
  guard let arr = raw as? [[String: Any]] else {
    // JSONSerialization may give [Any]
    guard let mixed = raw as? [Any] else {
      return []
    }
    return parseCommandList(mixed)
  }
  return parseCommandList(arr)
}

private func parseCommandList(_ raw: [Any]) -> [SlashCommand] {
  var out: [SlashCommand] = []
  for item in raw {
    if out.count >= commandsMax {
      break
    }
    guard let obj = JSON.dict(item) else {
      continue
    }
    let name = ((obj["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let hint = ((obj["hint"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let range = NSRange(name.startIndex..<name.endIndex, in: name)
    if nameRegex.firstMatch(in: name, range: range) == nil || name.count > commandNameMax {
      continue
    }
    if hint.count < 3 || hint.count > commandHintMax {
      continue
    }
    let args = JSON.bool(obj, "args")
    out.append(SlashCommand(name: name, hint: hint, args: args))
  }
  return out
}
