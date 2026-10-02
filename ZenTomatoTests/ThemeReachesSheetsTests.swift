import SwiftUI
import Testing
import UIKit

@testable import ZenTomato

/// **The theme reaches what UIKit draws inside a sheet.** Found on the owner's phone, 2026-10-02:
/// under Ripen, selecting a task in "Choose what to work on" turned its row Sage green.
///
/// `ThemeTests` resolves colours in a hand-built environment, which is why it stayed green: the
/// defect is in *where* the colour is resolved, not in what the rule returns. So this test draws the
/// real shape — a sheet, a navigation stack, a pushed list, a row background — into a real window,
/// and reads the pixels back.
@Suite("Theme reaches sheets", .serialized)
@MainActor
struct ThemeReachesSheetsTests {
  @Test("aSelectedRowInAPushedSheetPaintsTheTheme")
  func aSelectedRowInAPushedSheetPaintsTheTheme() async throws {
    let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
    window.overrideUserInterfaceStyle = .light
    window.rootViewController = UIHostingController(rootView: Host().appTheme(.ripen))
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      scene.traitOverrides.remove(ThemeTrait.self)
    }
    try await Task.sleep(for: .milliseconds(2500))

    let painted = Self.columnColours(in: scene, size: window.bounds.size, x: 30)
    let ripen = ColorRole.actionSubtle.light(in: .ripen).description
    let sage = ColorRole.actionSubtle.light(in: .sage).description
    #expect(painted.contains(ripen), "The selected row never painted Ripen's \(ripen). Saw: \(painted)")
    #expect(!painted.contains(sage), "The selected row painted Sage's \(sage) under Ripen.")
  }

  /// A sheet over a navigation stack with one screen pushed — the task picker's shape.
  private struct Host: View {
    @State private var shown = true
    @State private var path = [1]

    var body: some View {
      Color.white.sheet(isPresented: $shown) {
        NavigationStack(path: $path) {
          Text("Projects").navigationDestination(for: Int.self) { _ in
            List {
              Text(" ").frame(maxWidth: .infinity, minHeight: 80)
                .listRowBackground(Color(.actionSubtle))
            }
          }
        }
      }
    }
  }

  /// Every colour down one column of the screen, as `#RRGGBB`.
  private static func columnColours(in scene: UIWindowScene, size: CGSize, x: Int) -> Set<String> {
    let image = UIGraphicsImageRenderer(size: size).image { _ in
      for window in scene.windows where !window.isHidden {
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
      }
    }
    guard let cg = image.cgImage else { return [] }
    let width = cg.width
    let height = cg.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard
      let context = CGContext(
        data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return [] }
    context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
    let column = x * Int(image.scale)
    return Set(
      stride(from: 0, to: height, by: 4).map { row in
        let offset = (row * width + column) * 4
        return String(format: "#%02X%02X%02X", pixels[offset], pixels[offset + 1], pixels[offset + 2])
      })
  }
}
