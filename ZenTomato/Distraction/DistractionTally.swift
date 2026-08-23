/// What kind of thing pulled your attention away.
///
/// The spec calls these I and E. Two cases and no more: the point of the log is
/// that it takes under a second to record, and a longer list would turn a tap
/// into a decision.
enum DistractionKind: Codable, Hashable, Sendable {
  /// Your own head — you drifted, remembered something, wanted to check a thing.
  ///
  /// Named `internalInterruption` rather than `internal` because `internal` is a Swift
  /// keyword (it is an access level, like `private`). You could force it through
  /// with backticks — `` `internal` `` — but a name that needs escaping every
  /// time it is written is a name that will eventually be written wrong.
  case internalInterruption

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
        // The bail-out first, and the real work after it. That ordering is the
        // whole reason `guard` exists rather than `if`: because its `else` is
        // required to leave, every line below it is reached only when there is
        // something to summarise, and the function never nests.
        //
        // WORTH KNOWING, BECAUSE IT CATCHES EVERYONE ONCE
        // `guard <condition> else { }` states the condition for CARRYING ON, not
        // the condition for entering the block. `guard kinds.isEmpty` therefore
        // reads "kinds had better be empty", which is the opposite of what is
        // wanted here — and the symptom is perfectly swapped answers: the empty
        // array returning a summary and a full one saying "No distractions".
        //
        // The first working version of this function got the same effect by
        // keeping that condition and swapping the two BODIES instead, putting
        // the counting inside the `else`. It passed every test. It was rewritten
        // anyway: an `else` holding the entire function, with the one-line case
        // falling through beneath it, reads backwards to anyone who knows what
        // `guard` is for.
        guard !kinds.isEmpty else {
            return "No distractions"
        }

        let internalCount = kinds.filter { $0 == .internalInterruption }.count
        let externalCount = kinds.filter { $0 == .externalInterruption }.count

        // Collected as pieces rather than chosen from a set of combinations.
        // With two kinds there are three combinations to enumerate and get right;
        // with a third kind there would be seven. Asking one question about one
        // number, twice, has no combinations to forget — and it is why nothing
        // here mentions ordering even though the order is guaranteed: internal is
        // appended first, so it is first.
        //
        // A count of zero is left out entirely. "1 internal · 0 external" is
        // noise, and a reader would have to subtract it back out every time.
        var pieces: [String] = []
        if internalCount > 0 { pieces.append("\(internalCount) internal") }
        if externalCount > 0 { pieces.append("\(externalCount) external") }

        return pieces.joined(separator: " · ")
    }
}
