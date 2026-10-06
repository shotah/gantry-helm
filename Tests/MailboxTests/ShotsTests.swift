import XCTest

@testable import Mailbox

final class ShotsTests: XCTestCase {
  func testLaunchShotReadsDashAndEquals() {
    let shot = launchDocShot(["Helm", "-shot", "phone-thread-lamp"])
    XCTAssertEqual("phone-thread-lamp", shot?.file)
    XCTAssertEqual("thread", shot?.sample)
    XCTAssertEqual("lamp", shot?.theme)
    XCTAssertEqual("", shot?.open)
    XCTAssertEqual("settings", launchDocShot(["--shot=phone-settings"])?.open)
    XCTAssertEqual("draft", docShot("phone-draft")?.open)
    XCTAssertNil(launchDocShot(["-shot"]))
    XCTAssertNil(launchDocShot(["--shot=car-thread"]))
    XCTAssertNil(docShot("nope"))
  }

  func testEveryShotUsesAKnownSampleAndTheme() {
    XCTAssertEqual(14, docShots.count)
    for shot in docShots {
      XCTAssertNotNil(sampleScene(shot.sample), shot.file)
      XCTAssertEqual(shot.theme, knownTheme(shot.theme) ?? "", shot.file)
      XCTAssertTrue(
        ["", "settings", "emoji", "attach", "draft", "react", "keyboard"].contains(shot.open),
        shot.file)
    }
  }
}
