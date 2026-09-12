import XCTest
@testable import Mailbox

final class SamplesTests: XCTestCase {
  func testParseSampleAcceptsKnownIds() {
    XCTAssertEqual("thread", parseSample("Thread"))
    XCTAssertNil(parseSample("nope"))
    XCTAssertNil(parseSample(nil))
  }

  func testThreadSceneMatchesPendantCopy() {
    let scene = sampleScene("thread")!
    XCTAssertTrue(scene.up)
    XCTAssertEqual(4, scene.lines.count)
    XCTAssertEqual("On the dock — is the gate still open?", scene.lines.first?.text)
    XCTAssertEqual("Leave-by 20:50. Pin is this-send, ±12m.", scene.lines.last?.text)
  }

  func testRemainingScenesCoverTheDoors() {
    let unsigned = sampleScene("unsigned")!
    XCTAssertEqual("", unsigned.email)
    XCTAssertFalse(unsigned.up)
    XCTAssertTrue(unsigned.lines.isEmpty)

    let empty = sampleScene("empty")!
    XCTAssertTrue(empty.up)
    XCTAssertTrue(empty.lines.isEmpty)

    let ping = sampleScene("ping")!
    XCTAssertEqual("push", ping.lines.first?.kind)
    XCTAssertEqual(3, ping.lines.count)

    let down = sampleScene("down")!
    XCTAssertFalse(down.up)
    XCTAssertEqual(1, down.lines.count)
    XCTAssertTrue(down.lines.first?.pending == true)

    let stream = sampleScene("stream")!
    XCTAssertTrue(stream.up)
    XCTAssertTrue(stream.typing)
    XCTAssertEqual("draft", stream.lines.last?.kind)
    XCTAssertEqual(draftId, stream.lines.last?.id)

    let photo = sampleScene("photo")!
    XCTAssertTrue(photo.lines.first?.photo?.hasPrefix("data:image/jpeg") == true)
    XCTAssertEqual("This the right hatch?", photo.lines.first?.text)
  }

  func testReversedGoogleClientIdIsTheUrlScheme() {
    XCTAssertEqual(
      "com.googleusercontent.apps.prefix",
      reversedGoogleClientId("prefix.apps.googleusercontent.com")
    )
    XCTAssertEqual("", reversedGoogleClientId(""))
    XCTAssertEqual("", reversedGoogleClientId("not-a-google-id"))
  }
}
