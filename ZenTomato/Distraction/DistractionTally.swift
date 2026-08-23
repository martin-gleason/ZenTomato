/// What kind of thing pulled your attention away.
///
/// The spec calls these I and E. Two cases and no more: the point of the log is
/// that it takes under a second to record, and a longer list would turn a tap
/// into a decision.
enum DistractionKind: Codable, Hashable, Sendable {
  /// Your own head — you drifted, remembered something, wanted to check a thing.
  ///
  /// Named `internalPull` rather than `internal` because `internal` is a Swift
  /// keyword (it is an access level, like `private`). You could force it through
  /// with backticks — `` `internal` `` — but a name that needs escaping every
  /// time it is written is a name that will eventually be written wrong.
  case internalPull

  /// Someone or something else — a person, a phone call, a knock at the door.
  case externalInterruption
}

// MARK: - DistractionTally

/// Turns a pomodoro's taps into one line a person can read.
///
/// An `enum` with no cases, used only as a namespace. That is a Swift idiom: it
/// groups related functions under a name without ever being something you can
/// create an instance of. A `struct` would let somebody write
/// `DistractionTally()`, which would be meaningless here.
enum DistractionTally {
  /// A one-line summary of what interrupted a pomodoro.
  ///
  /// | Given | Returns |
  /// |---|---|
  /// | nothing | `"No distractions"` |
  /// | one internal | `"1 internal"` |
  /// | two internal | `"2 internal"` |
  /// | one external | `"1 external"` |
  /// | two internal, one external | `"2 internal · 1 external"` |
  ///
  /// Internal always comes first, whatever order the taps arrived in. A kind
  /// with no taps is left out entirely rather than printed as a zero.
  ///
  /// The separator is a middle dot with a space either side: `" · "`.
  ///
  /// - Parameter kinds: every tap recorded during the block, in any order.
  /// - Returns: the summary line.
  static func summary(of kinds: [DistractionKind]) -> String {
    // ── Write your code here. ────────────────────────────────────────────────
    //
    // The tests in ZenTomatoTests/DistractionTallyTests.swift describe exactly
    // what this has to do. Run them with Cmd-U in Xcode; they are red now and
    // your job is to make them green.
    //
    // Delete this comment and the line below when you start.
    ""
  }
}
