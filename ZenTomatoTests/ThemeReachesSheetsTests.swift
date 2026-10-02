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

    let painted = Self.columnColours(in: window, x: 30)
    let ripen = ColorRole.actionSubtle.light(in: .ripen).description
    let sage = ColorRole.actionSubtle.light(in: .sage).description
    #expect(painted.contains(ripen), "The selected row never painted Ripen's \(ripen). Saw: \(painted)")
    #expect(!painted.contains(sage), "The selected row painted Sage's \(sage) under Ripen.")
  }

  /// **The garden's tomatoes are the theme's tomatoes, in the sheet it really opens in** (`F16-T3`).
  ///
  /// Under Ripen the fruit is Ripen's red. Drawn through the real screen — `GardenView`, its Canvas,
  /// the tomato resolved as a Canvas symbol — inside a presented sheet, which is where this morning's
  /// row-background defect hid. Every pixel of the screen is read, not one column, because the
  /// tomatoes are small and their places depend on the width.
  @Test("theGardenGrowsTheThemesTomato")
  func theGardenGrowsTheThemesTomato() async throws {
    let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
    window.overrideUserInterfaceStyle = .light
    let garden = Color.white.sheet(isPresented: .constant(true)) {
      GardenView(countFinishedPoms: { 40 })
    }
    window.rootViewController = UIHostingController(rootView: garden.appTheme(.ripen))
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      scene.traitOverrides.remove(ThemeTrait.self)
    }
    try await Task.sleep(for: .milliseconds(2500))

    let painted = Self.colours(in: window)
    let ripen = ColorRole.tomatoFlesh.light(in: .ripen).description
    // **Sage's leaf, not Sage's fruit.** The first draft looked for Sage's fruit and failed on a
    // correct screen: Ripen's crown *is* Sage's fruit colour (`sage400`, `Theme.sageCrown`), so that
    // fixture could not tell the two themes apart. Sage's leaf is drawn by no part of Ripen's tomato.
    let sageOnly = ColorRole.tomatoLeaf.light(in: .sage).description
    let ripenTomato = [ColorRole.tomatoFlesh, .tomatoSkin, .tomatoLeaf].map { $0.light(in: .ripen).description }
    try #require(!ripenTomato.contains(sageOnly), "Sage's leaf is also a Ripen colour; this test would see nothing.")
    #expect(painted.contains(ripen), "The garden never painted Ripen's fruit \(ripen).")
    #expect(!painted.contains(sageOnly), "The garden painted Sage's leaf \(sageOnly) under Ripen.")
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

  /// Every colour on the screen, read every third pixel each way, as `#RRGGBB`.
  private static func colours(in window: UIWindow) -> Set<String> {
    guard let shot = Screenshot(window: window) else { return [] }
    return Set(stride(from: 0, to: shot.height, by: 3).flatMap { row in
      stride(from: 0, to: shot.width, by: 3).map { shot.hex(x: $0, y: row) }
    })
  }

  /// Every colour down one column of the screen, as `#RRGGBB`.
  private static func columnColours(in window: UIWindow, x: Int) -> Set<String> {
    guard let shot = Screenshot(window: window) else { return [] }
    let column = x * shot.scale
    return Set(stride(from: 0, to: shot.height, by: 4).map { shot.hex(x: column, y: $0) })
  }

  /// The visible windows drawn once into plain RGBA bytes.
  private struct Screenshot {
    let pixels: [UInt8]
    let width: Int
    let height: Int
    let scale: Int

    /// Only the test's own window. A sheet is drawn inside the window that presents it, and the app
    /// this suite runs inside has a window of its own underneath — the first draft drew every window
    /// and found the host app's Sage button behind the garden.
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
}
