import Foundation
import Mailbox
#if canImport(CoreLocation)
import CoreLocation
#endif

/// When-in-use fixes → `Geo`. Off until Settings / attach toggles GPS.
final class HelmLocation: NSObject {
  var onFix: ((Geo) -> Void)?
  #if canImport(CoreLocation)
  private let manager = CLLocationManager()
  #endif

  override init() {
    super.init()
    #if canImport(CoreLocation)
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    #endif
  }

  func setEnabled(_ on: Bool) {
    #if canImport(CoreLocation)
    if on {
      manager.requestWhenInUseAuthorization()
      manager.startUpdatingLocation()
    } else {
      manager.stopUpdatingLocation()
    }
    #endif
  }
}

#if canImport(CoreLocation)
extension HelmLocation: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last else {
      return
    }
    let heading = loc.course >= 0 ? loc.course : nil
    let speed = loc.speed >= 0 ? loc.speed : nil
    onFix?(
      geoFromFix(
        lat: loc.coordinate.latitude,
        lon: loc.coordinate.longitude,
        accuracyM: loc.horizontalAccuracy,
        altM: loc.altitude,
        heading: heading,
        speedMps: speed
      )
    )
  }
}
#endif
