import Foundation

/// The legal range of every number the settings screen can set.
///
/// WHY THESE LIVE IN ONE PLACE
/// Two entirely different pieces of code need to agree about them: the
/// settings screen, which must not offer a value outside the range, and the
/// snapshot taken when a block starts, which clamps whatever it finds in the
/// database back inside it. If each carried its own copy of "1 to 120" they
/// could drift, and the drift would show up as a timer that accepts a value it
/// then quietly changes. One definition makes that impossible.
///
/// It is an `enum` with no cases — Swift's way of writing "a namespace, not a
/// thing". There is never an instance of `SettingsBounds`; it only holds the
/// two ranges below.
enum SettingsBounds {
  /// How long any one block may be, in minutes.
  ///
  /// ONE MINUTE IS A REAL SETTING, NOT A DEBUG AFFORDANCE.
  /// It is what makes the whole cycle — work, short, work, short, work, short,
  /// work, long — testable by hand in about eight minutes instead of two
  /// hours, which is the only reason this feature's device check is a
  /// practical thing to ask anybody to perform. It is deliberately reachable
  /// by the user and not hidden behind a developer flag.
  ///
  /// The upper bound exists so that a mistaken value cannot schedule an alarm
  /// days into the future.
  static let minutes: ClosedRange<Int> = 1...120

  /// How many focus blocks make up one sprint.
  ///
  /// One is legal and is the interesting edge: with a sprint of one, every
  /// focus block is followed by the long break and a short break never occurs
  /// at all. That is correct behaviour rather than an oversight, and it has a
  /// test of its own.
  static let pomodorosPerSprint: ClosedRange<Int> = 1...12
}

extension ClosedRange where Bound == Int {
  /// Returns `value` if it is inside the range, or the nearer end of the range
  /// if it is not.
  ///
  /// This is the second line of defence behind the settings screen. The screen
  /// offers only legal values, so in normal use this never changes anything —
  /// but a value can also arrive from a database written by an older build, and
  /// a block whose length came out of a file is not a block whose length was
  /// chosen.
  func clamping(_ value: Bound) -> Bound {
    // `Swift.` qualified because inside an extension on `ClosedRange` the bare
    // names would resolve to the range's own clamping methods in a future Swift.
    Swift.min(Swift.max(value, lowerBound), upperBound)
  }
}
