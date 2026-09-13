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

/// Communication notification category. CarPlay reads this card; Reply
/// uses `kitReplyAction`. Must stay in lockstep with `HelmNotify`.
public let kitReplyCategory = "kit.reply"
public let kitReplyAction = "reply"
public let kitReplyThread = "kit"
public let kitReplyPreview = "Kit"
/// `AVAudioSession.Port.carAudio.rawValue` — CarPlay / car Bluetooth.
public let carAudioPort = "CarAudio"

/// Cab watches `CarConnection`. Helm watches the car-audio route.
public func carPlayRouteAttached(portTypes: [String]) -> Bool {
  portTypes.contains(carAudioPort)
}

/// Spoken Reply / lock-screen text. Empty is not a turn.
public func carPlayReplyText(_ raw: String?) -> String? {
  let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  return t.isEmpty ? nil : t
}

/**
 Body of the Kit card Helm would post, or nil if the gate skips it.
 Same decisions as `HelmModel.ingest` — test this, not UIKit.
 */
public func kitNoticeBody(
  painted: Bool,
  kind: String?,
  replay: Bool,
  resumed: Bool,
  carAttached: Bool,
  threadVisible: Bool,
  text: String?,
  hasPhoto: Bool
) -> String? {
  if !painted {
    return nil
  }
  if !shouldSpeak(kind, replay: replay) {
    return nil
  }
  if !shouldPost(
    resumed: resumed, carAttached: carAttached, kind: kind, threadVisible: threadVisible
  ) {
    return nil
  }
  return notifyBody(text, hasPhoto: hasPhoto)
}

public func shouldSweepNow(watching: Bool, openedAt: Int64, now: Int64) -> Bool {
  watching && now - openedAt >= sweepMinGapMs
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
