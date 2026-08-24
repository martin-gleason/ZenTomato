import Foundation

/// What the phone tells the watch about the block that is running.
///
/// **THE PHONE IS THE SOURCE OF TRUTH AND THIS IS THE WHOLE OF WHAT CROSSES.**
/// D2: *"The phone is the source of truth and runs the only timer engine."* So
/// this carries facts, never instructions: there is no field here the watch acts
/// on, and nothing it could send back that would change a block.
///
/// **`endsAt` is an absolute instant, not a remaining duration**, and that is the
/// load-bearing decision in this type. A duration is wrong the moment it is sent
/// — it decays in flight and again every second the connection is quiet — so the
/// watch would need a fresh message every second to stay right, which is exactly
/// the traffic a wrist has no battery for. An instant is still true twenty
/// minutes later, so the watch draws its countdown from it locally and the phone
/// can say nothing at all until the block changes.
///
/// **What is deliberately absent.** No identifiers beyond the session's, no
/// counts, no history, no distraction totals. The watch shows what is happening
/// now; everything else is a screen on the phone. A count on the wrist is also
/// one step from a score, and `SPEC.md` excludes gamification.
struct WatchBlockState: Codable, Equatable, Sendable {
  /// The block the timer is running, or `nil` when nothing is running.
  ///
  /// Optional rather than a separate "is running" flag, because two fields that
  /// can disagree eventually do: a `false` beside a populated block is a state
  /// nobody designed, and the watch would have to decide which to believe.
  var block: Block?

  /// One running block, as the wrist needs to see it.
  struct Block: Codable, Equatable, Sendable {
    /// Which of the three kinds this is. The watch draws the name; it never
    /// decides what follows one.
    var kind: BlockKind

    /// When it ends. Absolute, so a silent connection costs nothing.
    var endsAt: Date

    /// What the block is attached to, already resolved to a title by the phone.
    ///
    /// A title, never an identifier: the watch has no cache to resolve one
    /// against and no business holding Todoist's ids.
    var taskTitle: String?

    /// The session the phone will attribute a tap to. Sent so a tap can name the
    /// block it happened in even if it is delivered long afterwards.
    var sessionID: UUID
  }

  /// Whether this block accepts distraction taps.
  ///
  /// `SPEC.md`: the two buttons are *"tappable during a pomodoro"*. A break is
  /// not a pomodoro, so the wrist hides them rather than showing something that
  /// would refuse — F5 settled the same question on the phone and this matches
  /// it.
  var acceptsTaps: Bool {
    block?.kind == .work
  }
}
