import Foundation
import Mailbox
import UserNotifications
import Intents

enum HelmNotify {
  static let category = "kit.reply"
  static let thread = "kit"

  static func setup() {
    let reply = UNTextInputNotificationAction(
      identifier: "reply",
      title: "Reply",
      options: [],
      textInputButtonTitle: "Send",
      textInputPlaceholder: "Message"
    )
    let cat = UNNotificationCategory(
      identifier: category,
      actions: [reply],
      intentIdentifiers: [INSendMessageIntent.intentIdentifier],
      hiddenPreviewsBodyPlaceholder: "Kit",
      options: [.allowInCarPlay, .allowAnnouncement]
    )
    UNUserNotificationCenter.current().setNotificationCategories([cat])
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .carPlay]) { _, _ in }
  }

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
    content.interruptionLevel = .timeSensitive
    let intent = INSendMessageIntent(
      recipients: [INPerson(
        personHandle: INPersonHandle(value: slug, type: .unknown),
        nameComponents: nil,
        displayName: displaySlug(slug),
        image: nil,
        contactIdentifier: nil,
        customIdentifier: slug
      )],
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
      )
    )
    if let update = try? content.updating(from: intent) {
      content.setValue(update.value(forKey: "content") ?? content, forKey: "self")
    }
    let req = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(req)
  }
}

final class HelmNotifyDelegate: NSObject, UNUserNotificationCenterDelegate {
  var onReply: ((String) -> Void)?

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let text = (response as? UNTextInputNotificationResponse)?.userText, !text.isEmpty {
      onReply?(text)
    }
    completionHandler()
  }
}
