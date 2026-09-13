import Foundation
import Mailbox
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Cab watches `CarConnection`. Helm watches the car-audio route — no
/// CarPlay entitlement required for that bit.
enum HelmCar {
  static func attached() -> Bool {
    #if canImport(AVFoundation)
    carPlayRouteAttached(
      portTypes: AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType.rawValue)
    )
    #else
    false
    #endif
  }

  static func start(_ onChange: @escaping (Bool) -> Void) {
    onChange(attached())
    #if canImport(AVFoundation)
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      onChange(attached())
    }
    #endif
  }
}
