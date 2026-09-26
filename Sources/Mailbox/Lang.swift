import Foundation

public struct Language: Equatable {
  public var id: String
  public var label: String
  public var speech: String

  public init(id: String, label: String, speech: String) {
    self.id = id
    self.label = label
    self.speech = speech
  }
}

public let languages = [
  Language(id: "en", label: "English", speech: "en-US"),
  Language(id: "ja", label: "日本語 · Japanese", speech: "ja-JP"),
  Language(id: "zh", label: "中文 · Mandarin", speech: "zh-CN"),
  Language(id: "vi", label: "Tiếng Việt · Vietnamese", speech: "vi-VN"),
]

public let langIds = languages.map(\.id)
public let defaultLang = "en"

private func languageRow(_ id: String?) -> Language {
  languages.first { $0.id == id } ?? languages[0]
}

public func parseLang(_ v: String?) -> String {
  languages.first { $0.id == v }?.id ?? defaultLang
}

public func langLabel(_ id: String) -> String {
  languageRow(id).label
}

public func speechLang(_ id: String) -> String {
  languageRow(id).speech
}
