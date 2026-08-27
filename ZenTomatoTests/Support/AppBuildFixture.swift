@testable import ZenTomato

extension AppBuild {
  /// The build every golden is written against.
  ///
  /// **Fixed, and that is the whole point.** `AppBuild.current` reads
  /// `Bundle.main`, which in a test bundle is the test bundle — so a document
  /// built from it would produce different bytes here than in the app, and the
  /// golden would have to be regenerated to pass. Regenerating a golden to make a
  /// test pass is the one thing `StatsMarkdownGoldenTests` forbids by name.
  ///
  /// The numbers are deliberately not today's. A fixture that tracked the real
  /// version would rewrite every golden on every release, turning a byte-for-byte
  /// comparison into a chore people learn to wave through.
  static let forGoldens = AppBuild(name: "ZenPom", version: "1.0.0", build: "1")
}
