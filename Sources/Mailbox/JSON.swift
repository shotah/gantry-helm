import Foundation
import CoreFoundation

enum JSON {
  static func object(_ raw: String) -> [String: Any]? {
    guard let data = raw.data(using: .utf8) else {
      return nil
    }
    return dict(try? JSONSerialization.jsonObject(with: data))
  }

  /// Linux JSONSerialization yields NSDictionary; `as? [String: Any]` is not enough.
  static func dict(_ raw: Any?) -> [String: Any]? {
    if let o = raw as? [String: Any] {
      return o
    }
    guard let o = raw as? NSDictionary else {
      return nil
    }
    var out: [String: Any] = [:]
    out.reserveCapacity(o.count)
    for (k, v) in o {
      guard let key = k as? String else { continue }
      out[key] = v
    }
    return out
  }

  static func array(_ raw: Any?) -> [Any]? {
    if let a = raw as? [Any] {
      return a
    }
    if let a = raw as? NSArray {
      return a.map { $0 as Any }
    }
    return nil
  }

  static func stringify(_ obj: [String: Any]) -> String {
    guard JSONSerialization.isValidJSONObject(obj),
      let data = try? JSONSerialization.data(withJSONObject: obj),
      let s = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }
    return s
  }

  static func string(_ obj: [String: Any], _ key: String) -> String? {
    guard let raw = obj[key], !(raw is NSNull) else {
      return nil
    }
    if let s = raw as? String {
      return s.isEmpty ? nil : s
    }
    return nil
  }

  static func bool(_ obj: [String: Any], _ key: String, default def: Bool = false) -> Bool {
    guard let raw = obj[key], !(raw is NSNull) else {
      return def
    }
    if let b = raw as? Bool {
      return b
    }
    if let n = raw as? NSNumber {
      return n.boolValue
    }
    return def
  }

  static func isNull(_ obj: [String: Any], _ key: String) -> Bool {
    obj[key] is NSNull
  }

  static func has(_ obj: [String: Any], _ key: String) -> Bool {
    obj[key] != nil
  }
}

/// Mailbox sequence / epoch: whole numbers only. Strings and 1.5 are junk.
public func jsonWholeNumber(_ raw: Any?) -> Int64? {
  guard let raw, !(raw is NSNull) else {
    return nil
  }
  // NSNumber(0)/NSNumber(1) are `is Bool` on Linux. Real JSON booleans
  // are CFBoolean — reject those, then read the number.
  if let n = raw as? NSNumber {
    if CFGetTypeID(n) == CFBooleanGetTypeID() {
      return nil
    }
    let d = n.doubleValue
    if !d.isFinite {
      return nil
    }
    let i = n.int64Value
    if Double(i) == d {
      return i
    }
    return nil
  }
  if raw is Bool {
    return nil
  }
  if let n = raw as? Int {
    return Int64(n)
  }
  if let n = raw as? Int64 {
    return n
  }
  if let n = raw as? Int32 {
    return Int64(n)
  }
  if let n = raw as? UInt, n <= UInt(Int64.max) {
    return Int64(n)
  }
  if let n = raw as? Double {
    if !n.isFinite {
      return nil
    }
    let i = Int64(n)
    if Double(i) == n {
      return i
    }
    return nil
  }
  if let n = raw as? Float {
    return jsonWholeNumber(Double(n))
  }
  return nil
}
