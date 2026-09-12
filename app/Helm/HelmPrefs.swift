import Foundation
import Mailbox

final class HelmPrefs {
  private let d: UserDefaults
  private var heldSpike: String

  init(defaults: UserDefaults = UserDefaults(suiteName: "helm") ?? .standard) {
    d = defaults
    heldSpike = Self.readSecret(Keys.spike, defaults: defaults)
  }

  var origin: String {
    get { nonEmpty(d.string(forKey: Keys.origin)) ?? HelmConfig.mailboxOrigin }
    set { d.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Keys.origin) }
  }

  var slug: String {
    get { (d.string(forKey: Keys.slug) ?? "kit") }
    set { d.set(newValue.trimmingCharacters(in: .whitespaces).lowercased(), forKey: Keys.slug) }
  }

  var spike: String {
    get { heldSpike }
    set { putSpike(newValue, persistToDisk: true) }
  }

  var session: String {
    get { Self.readSecret(Keys.session, defaults: d) }
    set {
      Self.writeSecret(Keys.session, newValue, defaults: d)
      if !newValue.isEmpty {
        heldSpike = ""
        Self.writeSecret(Keys.spike, "", defaults: d)
      }
    }
  }

  var sessionExp: Int64 {
    get { Int64(d.integer(forKey: Keys.sessionExp)) }
    set { d.set(Int(newValue), forKey: Keys.sessionExp) }
  }

  var email: String {
    get { Self.readSecret(Keys.email, defaults: d) }
    set { Self.writeSecret(Keys.email, newValue, defaults: d) }
  }

  var gps: Bool {
    get { d.string(forKey: Keys.gps) == "on" }
    set { d.set(newValue ? "on" : "off", forKey: Keys.gps) }
  }

  var theme: String {
    get { parseTheme(d.string(forKey: Keys.theme)) }
    set { d.set(parseTheme(newValue), forKey: Keys.theme) }
  }

  var font: String {
    get { parseFont(d.string(forKey: Keys.font)) }
    set { d.set(parseFont(newValue), forKey: Keys.font) }
  }

  var photoSize: String {
    get { parsePhotoSize(d.string(forKey: Keys.photo)) }
    set { d.set(parsePhotoSize(newValue), forKey: Keys.photo) }
  }

  var backdrop: Bool {
    get { d.string(forKey: Keys.backdrop) != "off" }
    set { d.set(newValue ? "on" : "off", forKey: Keys.backdrop) }
  }

  var followTheme: Bool {
    get { d.string(forKey: Keys.followTheme) != "off" }
    set { d.set(newValue ? "on" : "off", forKey: Keys.followTheme) }
  }

  var lastGeo: Geo? {
    get {
      guard d.object(forKey: Keys.geoLat) != nil else {
        return nil
      }
      return geoFromFix(
        lat: d.double(forKey: Keys.geoLat),
        lon: d.double(forKey: Keys.geoLon),
        accuracyM: d.object(forKey: Keys.geoAcc) == nil ? nil : d.double(forKey: Keys.geoAcc)
      )
    }
    set {
      if let g = newValue {
        d.set(g.lat, forKey: Keys.geoLat)
        d.set(g.lon, forKey: Keys.geoLon)
        if let a = g.accuracyM {
          d.set(a, forKey: Keys.geoAcc)
        }
      } else {
        d.removeObject(forKey: Keys.geoLat)
        d.removeObject(forKey: Keys.geoLon)
        d.removeObject(forKey: Keys.geoAcc)
      }
    }
  }

  func roomTheme(_ slug: String) -> String {
    knownTheme(d.string(forKey: "\(Keys.roomTheme).\(slug)")) ?? ""
  }

  func putRoomTheme(_ slug: String, id: String) {
    d.set(knownTheme(id) ?? "", forKey: "\(Keys.roomTheme).\(slug)")
  }

  func putSpike(_ value: String, persistToDisk: Bool) {
    heldSpike = value
    Self.writeSecret(Keys.spike, persistToDisk ? value : "", defaults: d)
  }

  func signOut() {
    Self.writeSecret(Keys.session, "", defaults: d)
    Self.writeSecret(Keys.email, "", defaults: d)
    d.removeObject(forKey: Keys.sessionExp)
  }

  static var threadFile: URL {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return dir.appendingPathComponent("helm/thread.json")
  }

  static var blobDir: URL {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return dir.appendingPathComponent("helm/blobs")
  }

  private static func readSecret(_ key: String, defaults: UserDefaults) -> String {
    if let boxed = HelmKeychain.get(key), !boxed.isEmpty {
      return boxed
    }
    let old = defaults.string(forKey: key) ?? ""
    if !old.isEmpty {
      HelmKeychain.set(key, old)
      defaults.removeObject(forKey: key)
    }
    return old
  }

  private static func writeSecret(_ key: String, _ value: String, defaults: UserDefaults) {
    HelmKeychain.set(key, value)
    defaults.removeObject(forKey: key)
  }

  private func nonEmpty(_ s: String?) -> String? {
    guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else {
      return nil
    }
    return s
  }

  private enum Keys {
    static let origin = "origin"
    static let slug = "slug"
    static let spike = "spike"
    static let session = "session"
    static let sessionExp = "session_exp"
    static let email = "email"
    static let gps = "gps"
    static let theme = "theme"
    static let font = "font"
    static let photo = "photo"
    static let backdrop = "backdrop"
    static let followTheme = "followTheme"
    static let roomTheme = "roomTheme"
    static let geoLat = "geo_lat"
    static let geoLon = "geo_lon"
    static let geoAcc = "geo_acc"
  }
}
