import Foundation

/// Pendant `haptic.ts` visible-push buzz.
public let pushBuzzMs: Int64 = 40

/**
 Kit HUNs and the CarPlay mouth. Post when a head unit is attached or the
 phone thread is not resumed. Skip while the Helm CarPlay conversation
 screen is open (that template is the mouth then). Maps / music keep
 HUNs because that screen is not started. `kind` is `reply` / `push`
 only — same as `shouldSpeak`.
 */
public func shouldPost(
  resumed: Bool,
  carAttached: Bool,
  kind: String?,
  threadVisible: Bool = false
) -> Bool {
  (kind == "reply" || kind == "push") && !threadVisible && (carAttached || !resumed)
}

/// Visible ping on the phone when we skipped the toast.
public func shouldBuzz(resumed: Bool, carAttached: Bool, kind: String?) -> Bool {
  kind == "push" && resumed && !carAttached
}

/**
 Settings → **Test car voice** would be a lie if iOS drops the card first.
 CarPlay reads time-sensitive / active communication notifications; a user
 can revoke them. `nil` = not asked yet.
 */
public func carTestBlocked(notificationsEnabled: Bool, channelImportance: Int?) -> Bool {
  !notificationsEnabled || (channelImportance != nil && channelImportance! < 4)
}

/**
 Body of the Kit notification posted by Settings → **Test car voice**.
 Goes through the same communication notification as a real reply, so
 CarPlay reads it aloud if the sideload is allowed and the phone is
 projecting. The text itself says what the phone sees.
 */
public func carCheckText(carAttached: Bool) -> String {
  if carAttached {
    return "Car check from Helm. CarPlay is attached. If you hear this, Kit will be read aloud."
  }
  return "Car check from Helm. The phone does not see CarPlay. Plug into the car, then tap Test again."
}
