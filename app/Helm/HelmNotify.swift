import Foundation
import Intents
import Mailbox
import UserNotifications

enum HelmNotify {
  static let category = kitReplyCategory
  static let thread = kitReplyThread

  /// What this signature may claim. A free Personal Team gets a plain card.
  private static let entitlements = profileEntitlements(
    Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
      .flatMap { try? Data(contentsOf: $0) }
  )
  static let communication = entitled(entitlements, communicationEntitlement)
  static let timeSensitive = entitled(entitlements, timeSensitiveEntitlement)

  static func setup() {
    let reply = UNTextInputNotificationAction(
      identifier: kitReplyAction,
      title: "Reply",
      options: [],
      textInputButtonTitle: "Send",
      textInputPlaceholder: "Message"
    )
    let cat = UNNotificationCategory(
      identifier: category,
      actions: [reply],
      // iOS 27 dropped INSendMessageIntent.intentIdentifier. Its value was the class name.
      intentIdentifiers: ["INSendMessageIntent"],
      hiddenPreviewsBodyPlaceholder: kitReplyPreview,
      options: [.allowInCarPlay]
    )
    UNUserNotificationCenter.current().setNotificationCategories([cat])
    UNUserNotificationCenter.current().requestAuthorization(options: [
      .alert, .sound, .badge, .carPlay,
    ]) { _, _ in }
  }

  /// The card uses the car's palette. A mood paints the handset only.
  static func postKit(slug: String, body: String, replay: Bool) {
    if replay {
      return
    }
    let content = UNMutableNotificationContent()
    content.title = displaySlug(slug)
    content.body = body
    content.categoryIdentifier = category
    content.threadIdentifier = thread
    content.sound = .default
    content.interruptionLevel = timeSensitive ? .timeSensitive : .active
    let req = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: communication ? communicationCard(content, slug: slug, body: body) : content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(req)
  }

  /// Avatar + CarPlay read-aloud. Only valid on a signature that carries
  /// `communicationEntitlement`; iOS drops an unentitled card that claims it.
  private static func communicationCard(
    _ content: UNNotificationContent, slug: String, body: String
  ) -> UNNotificationContent {
    let intent = INSendMessageIntent(
      recipients: [
        INPerson(
          personHandle: INPersonHandle(value: slug, type: .unknown),
          nameComponents: nil,
          displayName: displaySlug(slug),
          image: nil,
          contactIdentifier: nil,
          customIdentifier: slug
        )
      ],
      outgoingMessageType: .outgoingMessageText,
      content: body,
      speakableGroupName: INSpeakableString(spokenPhrase: displaySlug(slug)),
      conversationIdentifier: thread,
      serviceName: "Helm",
      sender: INPerson(
        personHandle: INPersonHandle(value: slug, type: .unknown),
        nameComponents: nil,
        displayName: displaySlug(slug),
        image: nil,
        contactIdentifier: nil,
        customIdentifier: slug
      ),
      attachments: nil
    )
    return (try? content.updating(from: intent)) ?? content
  }

  static func dismissKit() {
    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { notes in
      let ids = notes.filter { $0.request.content.threadIdentifier == thread }.map(
        \.request.identifier)
      center.removeDeliveredNotifications(withIdentifiers: ids)
    }
  }
}

final class HelmNotifyDelegate: NSObject, UNUserNotificationCenterDelegate {
  var onReply: ((String) -> Void)?

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let text = carPlayReplyText((response as? UNTextInputNotificationResponse)?.userText) {
      onReply?(text)
    }
    completionHandler()
  }
}
