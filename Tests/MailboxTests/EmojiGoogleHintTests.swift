import XCTest
@testable import Mailbox

final class EmojiGoogleHintTests: XCTestCase {
  func testShortcodesResolveNamesAndAliases() {
    XCTAssertEqual("🤷", emojiForShortcode("shrug"))
    XCTAssertEqual("🤷", emojiForShortcode("person_shrugging"))
    XCTAssertEqual("👍", emojiForShortcode("+1"))
    XCTAssertEqual("👍", emojiForShortcode("thumbs-up"))
    XCTAssertNil(emojiForShortcode("nope"))
  }

  func testFinishedColonNameConvertsAndUnknownStays() {
    let next = applyEmoji("well :shrug: ok", cursor: 13, whenTo: "type")
    XCTAssertEqual("well 🤷 ok", next.text)
    XCTAssertEqual(8, next.cursor)
    XCTAssertEqual("see :notacode: later", applyEmoji("see :notacode: later", cursor: 18, whenTo: "type").text)
    XCTAssertEqual("https://example.com", applyEmoji("https://example.com", cursor: 19, whenTo: "type").text)
  }

  func testGrinConvertsWhenFinishedAndOnSend() {
    XCTAssertEqual("yo :D", applyEmoji("yo :D", cursor: 5, whenTo: "type").text)
    XCTAssertEqual("yo 😀 ", applyEmoji("yo :D ", cursor: 6, whenTo: "type").text)
    XCTAssertEqual("yo 😀", applyEmoji("yo :D", cursor: 5, whenTo: "send").text)
    XCTAssertEqual("😀!", applyEmoji(":D!", cursor: 3, whenTo: "type").text)
    XCTAssertEqual("wow 🐶", applyEmoji("wow :dog:", cursor: 9, whenTo: "type").text)
  }

  func testClosedFacesConvertAndMidWordColonStays() {
    XCTAssertEqual("hi 😊", applyEmoji("hi :)", cursor: 5, whenTo: "type").text)
    XCTAssertEqual("see:(", applyEmoji("see:(", cursor: 6, whenTo: "type").text)
    XCTAssertEqual("😆 ", applyEmoji("xD ", cursor: 3, whenTo: "type").text)
    XCTAssertEqual("🙁.", applyEmoji(":(.", cursor: 3, whenTo: "type").text)
    XCTAssertEqual("(😊", applyEmoji("(:)", cursor: 3, whenTo: "type").text)
  }

  func testCaretParksAfterAReplacementThatContainsIt() {
    let next = applyEmoji(":shrug:", cursor: 4, whenTo: "type")
    XCTAssertEqual("🤷", next.text)
    XCTAssertEqual((next.text as NSString).length, next.cursor)
  }

  func testCursorPastTheEndIsClamped() {
    let next = applyEmoji("hi :)", cursor: 99, whenTo: "type")
    XCTAssertEqual("hi 😊", next.text)
    XCTAssertEqual((next.text as NSString).length, next.cursor)
  }

  func testPickerFiltersTheCatalog() {
    let idle = searchEmoji("")
    XCTAssertTrue(idle.contains { $0.name == "shrug" })
    XCTAssertTrue(idle.contains { $0.name == "sunny" })
    XCTAssertEqual(44, idle.count)
    XCTAssertTrue(idle.count < emojiCatalog.count)
    XCTAssertEqual(["fire"], searchEmoji(":fire").map(\.name))
    XCTAssertEqual(["fire"], searchEmoji("🔥").map(\.name))
    XCTAssertEqual([], searchEmoji("no-such-face"))
    let names = emojiCatalog.map(\.name)
    XCTAssertEqual(names.count, Set(names).count)
  }

  func testCancelledKeepsTheRawException() {
    let hint = googleSignInHint(
      className: "GIDSignInError.canceled",
      message: "cancelled"
    )
    XCTAssertTrue(hint.contains("URL-scheme") || hint.contains("client-id"))
    XCTAssertTrue(hint.contains("canceled") || hint.contains("cancelled"))
  }

  func testMissingClientExplainsConsole() {
    let none = googleSignInHint(className: "NoCredentialException", message: nil)
    XCTAssertTrue(none.contains("com.gantree.helm"))
    let console = googleSignInHint(
      className: "Exception",
      message: "During begin sign in, failure response from one tap: 16: [28444] Developer console is not set up correctly"
    )
    XCTAssertTrue(console.contains("iOS OAuth"))
    XCTAssertTrue(console.contains("28444"))
  }

  func testOtherMessagesPassThroughWithClass() {
    let hint = googleSignInHint(className: "java.io.IOException", message: "network down")
    XCTAssertTrue(hint.contains("network down"))
    XCTAssertTrue(hint.contains("IOException"))
  }
}
