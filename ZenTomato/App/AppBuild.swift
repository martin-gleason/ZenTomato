import Foundation

/// Which build of this app is running, as three plain strings.
///
/// **WHY THIS IS A TYPE RATHER THAN A CALL TO `Bundle.main`.**
/// The export's whole standard of proof is a golden file compared byte for byte,
/// and a document that reached into `Bundle.main` would produce different bytes in
/// the test bundle than in the app. The golden would then have to be regenerated
/// to pass, which is the one thing `StatsMarkdownGoldenTests` forbids by name.
///
/// So the value is **handed in** at every call site. `current` reads the bundle
/// exactly once, in the app; tests pass a fixed value and the page stays
/// deterministic.
///
/// WHY IT EXISTS AT ALL
/// A crash report arrived this week and the only way to find out which code the
/// owner was running was to read the build number off the phone with
/// `devicectl`. A tester cannot do that. An export filed in a paper notebook has
/// the same problem in slower motion: read six months later, nothing on the page
/// says what produced it.
struct AppBuild: Equatable, Sendable {
  /// What the app is called on the home screen — `ZenPom`, not `ZenTomato`.
  ///
  /// Read from the bundle rather than written here, because those two names
  /// differ on purpose and hard-coding either would be a third place for them to
  /// disagree.
  let name: String

  /// The marketing version, `0.9.0`.
  let version: String

  /// The build number, which rises on every upload.
  let build: String

  /// This running app.
  static var current: AppBuild {
    let info = Bundle.main.infoDictionary
    return AppBuild(
      name: info?["CFBundleDisplayName"] as? String
        ?? info?["CFBundleName"] as? String
        ?? "ZenPom",
      version: info?["CFBundleShortVersionString"] as? String ?? "—",
      build: info?["CFBundleVersion"] as? String ?? "—")
  }

  /// `ZenPom 0.9.0 (3)` — the one form used everywhere it is shown.
  ///
  /// One property rather than three call sites assembling it differently, so the
  /// Settings row and the export footer cannot come to disagree about how a
  /// version is written down.
  var described: String {
    "\(name) \(version) (\(build))"
  }
}
