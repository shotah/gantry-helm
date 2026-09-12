#if canImport(ImageIO)
import Foundation
import ImageIO
import CoreGraphics

func jpegFromImageDataIO(_ data: Data, edge: Int, maxBytes: Int) -> Data? {
  guard let src = CGImageSourceCreateWithData(data as CFData, nil) else {
    return nil
  }
  let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
  let width = intProp(props, kCGImagePropertyPixelWidth)
  let height = intProp(props, kCGImagePropertyPixelHeight)
  if width <= 0 || height <= 0 {
    return nil
  }
  let uti = (CGImageSourceGetType(src) as String?) ?? ""
  let jpeg = uti.contains("jpeg") || uti.contains("jpg")
  if jpeg,
    shouldPassthroughJpeg(
      type: "image/jpeg", size: data.count, width: width, height: height, edge: edge, maxBytes: maxBytes
    ),
    acceptJpeg(data).ok
  {
    return data
  }
  guard let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    return nil
  }
  let longest = max(image.width, image.height)
  return shrinkToFit(shrinkSteps(edge: edge, longest: longest), maxBytes: maxBytes) { step in
    encodeJpeg(image, step: step)
  }
}

private func intProp(_ props: [CFString: Any]?, _ key: CFString) -> Int {
  if let n = props?[key] as? Int {
    return n
  }
  if let n = props?[key] as? NSNumber {
    return n.intValue
  }
  return 0
}

private func encodeJpeg(_ image: CGImage, step: JpegStep) -> Data {
  let longest = max(image.width, image.height)
  let scale = min(1.0, Double(step.edge) / Double(max(longest, 1)))
  let dw = max(1, Int((Double(image.width) * scale).rounded()))
  let dh = max(1, Int((Double(image.height) * scale).rounded()))
  let dest: CGImage
  if dw == image.width && dh == image.height {
    dest = image
  } else if let drawn = scaled(image, width: dw, height: dh) {
    dest = drawn
  } else {
    return Data()
  }
  let out = NSMutableData()
  guard let destion = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else {
    return Data()
  }
  CGImageDestinationAddImage(
    destion,
    dest,
    [kCGImageDestinationLossyCompressionQuality: Double(step.quality) / 100.0] as CFDictionary
  )
  guard CGImageDestinationFinalize(destion) else {
    return Data()
  }
  return out as Data
}

private func scaled(_ image: CGImage, width: Int, height: Int) -> CGImage? {
  let cs = CGColorSpaceCreateDeviceRGB()
  guard let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
  ) else {
    return nil
  }
  ctx.interpolationQuality = .high
  ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
  return ctx.makeImage()
}
#endif
