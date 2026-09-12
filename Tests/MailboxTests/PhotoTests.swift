import XCTest
@testable import Mailbox

final class PhotoTests: XCTestCase {
  func testSmallJpegBecomesADataUrl() {
    let got = photoDataUrl(Data([1, 2, 3]), mime: "image/jpg")
    XCTAssertTrue(got.ok)
    guard case .ok(let url) = got else {
      return XCTFail()
    }
    XCTAssertTrue(url.hasPrefix("data:image/jpeg;base64,"))
    XCTAssertEqual(Data([1, 2, 3]), decodeDataUrl(url))
  }

  func testRejectsEmptyHugeAndNonImage() {
    if case .err(let error) = photoDataUrl(Data(), mime: "image/jpeg") {
      XCTAssertEqual("bad photo", error)
    } else {
      XCTFail()
    }
    if case .err(let error) = photoDataUrl(Data([1]), mime: "text/plain") {
      XCTAssertEqual("bad photo", error)
    } else {
      XCTFail()
    }
    if case .err(let error) = photoDataUrl(Data(count: imageBytesMax + 1), mime: "image/jpeg") {
      XCTAssertEqual("too large", error)
    } else {
      XCTFail()
    }
    XCTAssertTrue(parsePhotoFile(type: "image/png", size: 10).ok)
    XCTAssertFalse(parsePhotoFile(type: "application/pdf", size: 10).ok)
    XCTAssertFalse(parsePhotoFile(type: "image/jpeg", size: 0).ok)
    if case .err(let error) = parsePhotoFile(type: "image/jpeg", size: imageBytesMax + 1) {
      XCTAssertEqual("too large", error)
    } else {
      XCTFail()
    }
  }

  func testComposeTurnAllowsAPhotoWithNoCaptionAndIgnoresABlank() {
    XCTAssertFalse(composeHasTurn(text: "", photo: nil))
    XCTAssertFalse(composeHasTurn(text: "  ", photo: nil))
    XCTAssertTrue(composeHasTurn(text: "", photo: "data:image/jpeg;base64,QQ"))
    XCTAssertTrue(composeHasTurn(text: "this hatch?", photo: nil))
    XCTAssertTrue(composeHasTurn(text: "this hatch?", photo: "data:image/jpeg;base64,QQ"))
  }

  func testJpegBudgetMatchesPendantAndKeepsTheDataUrlUnderTheWireCap() {
    XCTAssertEqual(1_124_976, photoJpegBytesMax)
    let fits = photoDataUrl(Data(count: photoJpegBytesMax), mime: "image/jpeg")
    XCTAssertTrue(fits.ok)
    if case .ok(let url) = fits {
      XCTAssertTrue(Array(url.utf8).count <= imageBytesMax)
    } else {
      XCTFail()
    }
    if case .err(let error) = photoDataUrl(Data(count: photoJpegBytesMax + 1), mime: "image/jpeg") {
      XCTAssertEqual("too large", error)
    } else {
      XCTFail()
    }
  }

  func testPhotoSizesMatchThePendantTable() {
    XCTAssertEqual(["full", "medium", "small"], photoSizeIds)
    XCTAssertEqual("medium", defaultPhotoSize)
    XCTAssertEqual(defaultPhotoSize, parsePhotoSize(nil))
    XCTAssertEqual("medium", parsePhotoSize("nope"))
    XCTAssertEqual("small", parsePhotoSize("small"))
    XCTAssertEqual(chatPhotoEdge, photoEdge("full"))
    XCTAssertEqual(1024, photoEdge("medium"))
    XCTAssertEqual(640, photoEdge("small"))
    XCTAssertEqual(1024, photoEdge(nil))
    XCTAssertEqual("Full", photoSizeLabel("full"))
    XCTAssertEqual("Medium", photoSizeLabel("nope"))
    XCTAssertEqual("Small · 640 px", photoSizeChip("small"))
  }

  func testLadderStepsQualityDownThenTheEdgeUntilTheFloor() {
    XCTAssertEqual([90, 80, 70, 60], jpegQualitySteps)
    let steps = shrinkSteps(edge: 1600, longest: 4000)
    XCTAssertEqual(JpegStep(edge: 1600, quality: 90), steps.first)
    XCTAssertEqual([90, 80, 70, 60], steps.filter { $0.edge == 1600 }.map(\.quality))
    XCTAssertEqual([1600, 1200, 900, 675, 506, 380], uniqueInts(steps.map(\.edge)))
    let smallest = steps.last!.edge
    XCTAssertTrue(smallest >= jpegEdgeMin)
    XCTAssertTrue(smallest < 480)
    XCTAssertEqual(JpegStep(edge: 380, quality: 60), steps.last)
  }

  func testLadderNeverUpscalesASmallImage() {
    let steps = shrinkSteps(edge: 1600, longest: 1000)
    XCTAssertEqual(JpegStep(edge: 1000, quality: 90), steps.first)
    XCTAssertEqual([1000, 750, 563, 422], uniqueInts(steps.map(\.edge)))
  }

  func testShrinkToFitTakesTheFirstEncodeUnderBudgetOrGivesUp() {
    var tried: [JpegStep] = []
    let got = shrinkToFit(shrinkSteps(edge: 1600, longest: 4000), maxBytes: 300_000) { step in
      tried.append(step)
      let h = step.edge * 3 / 4
      return Data(count: step.edge * h * step.quality / 100 * 3 / 10)
    }
    XCTAssertTrue(got!.count <= 300_000)
    XCTAssertEqual([90, 80, 70, 60], tried.filter { $0.edge == 1600 }.map(\.quality))
    XCTAssertEqual([1600, 1200], uniqueInts(tried.map(\.edge)))
    XCTAssertEqual(1200, tried.last?.edge)
    XCTAssertNil(shrinkToFit(shrinkSteps(edge: 1600, longest: 4000), maxBytes: 1_000) { _ in Data(count: 500_000) })
    XCTAssertNil(shrinkToFit([], maxBytes: 10) { _ in Data(count: 1) })
  }

  func testDecodeRequiresADataImage() {
    XCTAssertNil(decodeDataUrl("https://example.test/a.jpg"))
    XCTAssertNil(decodeDataUrl("data:text/plain;base64,YQ=="))
    XCTAssertNil(decodeDataUrl("data:image/jpeg;base64,!!!!"))
    // Linux Data(base64Encoded:) rejects missing padding; Apple does not.
    XCTAssertEqual(Data([0x41]), decodeDataUrl("data:image/jpeg;base64,QQ"))
    XCTAssertEqual(Data([0x69]), decodeDataUrl("data:image/jpeg;base64,aa"))
    let wrapped = "data:image/png;base64,\nAQID"
    XCTAssertEqual(Data([1, 2, 3]), decodeDataUrl(wrapped))
    let huge = "data:image/jpeg;base64," + String(repeating: "A", count: 2_100_000)
    XCTAssertNil(decodeDataUrl(huge))
  }

  func testJpegFromImageDataKeepsASmallJpeg() {
    let jpeg = fakeJpeg()
    #if canImport(ImageIO)
    XCTAssertNil(jpegFromImageData(Data([1, 2, 3]), edge: 1600, maxBytes: photoJpegBytesMax))
    #else
    XCTAssertEqual(jpeg, jpegFromImageData(jpeg, edge: 1600, maxBytes: photoJpegBytesMax))
    XCTAssertNil(jpegFromImageData(Data([1, 2, 3]), edge: 1600, maxBytes: photoJpegBytesMax))
    #endif
  }
}

private func uniqueInts(_ xs: [Int]) -> [Int] {
  var seen = Set<Int>()
  return xs.filter { seen.insert($0).inserted }
}
