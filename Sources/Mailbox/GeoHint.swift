import Foundation

/// Reuse a recent fix on send; do not wait for a new satellite lock.
public let geoCacheMs: Int64 = 120_000
/// lastLocation is cached; keep the send path snappy.
public let geoLastKnownMs: Int64 = 250

public func geoHint(enabled: Bool, geo: Geo?) -> String {
  if !enabled {
    return "GPS off"
  }
  if let geo {
    let m = Int((geo.accuracyM ?? 0).rounded())
    return "pin ±\(m)m this send"
  }
  return "GPS omitted (denied or unavailable)"
}

/// Text send: only show a hint when a pin actually went out. Omitted is not a failed send.
public func sendGeoHint(enabled: Bool, geo: Geo?) -> String? {
  if !enabled || geo == nil {
    return nil
  }
  return geoHint(enabled: true, geo: geo)
}

/// Clamp to what the Durable Object will accept so the pin is not `bad frame`.
public func geoFromFix(
  lat: Double,
  lon: Double,
  accuracyM: Double? = nil,
  altM: Double? = nil,
  heading: Double? = nil,
  speedMps: Double? = nil
) -> Geo {
  Geo(
    lat: lat,
    lon: lon,
    accuracyM: accuracyM.flatMap { $0 >= 0 ? $0 : nil },
    altM: altM,
    heading: heading.flatMap { $0 >= 0 && $0 < 360 ? $0 : nil },
    speedMps: speedMps.flatMap { $0 >= 0 ? $0 : nil }
  )
}
