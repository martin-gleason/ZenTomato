import UIKit

/// One window drawn once into plain RGBA bytes, for tests that judge what was actually painted.
struct Screenshot: Equatable, CustomStringConvertible {
  let pixels: [UInt8]
  let width: Int
  let height: Int
  let scale: Int

  /// Short on purpose. A failed comparison prints both sides, and a million bytes of pixels took a
  /// failing test from three seconds to sixty.
  var description: String {
    "Screenshot(\(width)×\(height), \(pixels.reduce(0) { ($0 &* 31) &+ Int($1) }))"
  }

  /// Only the test's own window. A sheet is drawn inside the window that presents it, and the app
  /// this suite runs inside has a window of its own underneath — the first draft drew every window
  /// and found the host app's Sage button behind the garden.
  @MainActor
  init?(window: UIWindow) {
    let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
      window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
    guard let cg = image.cgImage else { return nil }
    var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
    guard
      let context = CGContext(
        data: &pixels, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    self.pixels = pixels
    self.width = cg.width
    self.height = cg.height
    self.scale = Int(image.scale)
  }

  func hex(x: Int, y: Int) -> String {
    let offset = (y * width + x) * 4
    return String(format: "#%02X%02X%02X", pixels[offset], pixels[offset + 1], pixels[offset + 2])
  }
}
