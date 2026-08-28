import Foundation

/// Everything the end-of-block sheet needs in order to be presented: which
/// block just finished, and which taps it wants a sentence for.
///
/// WHAT IT DELIBERATELY DOES NOT CARRY
/// The *kind* of block that ended. Taps are only ever accepted during a focus
/// block, so the value would be the same on every instance and no screen reads
/// it; carrying it would also couple this type to `BlockKind`, which is one of
/// the two types compiled into the Live Activity's bundle, for nothing. F6 will
/// re-derive the block from the finished-block row when it needs to.
///
/// WHAT THIS IS FOR
/// When a work block ends and somebody could plausibly still be in it — the app
/// was awake to see it end, or `D29`'s prompt-wake test passes — the engine puts
/// one of these on `TimerEngine.pendingReflection`. The timer screen notices,
/// takes it, and presents the sheet. **The break is already running by then** —
/// the engine finishes the whole transition before it publishes this, so
/// reflection never eats into a break, and a sheet left open while somebody
/// walks away does not silently stretch their day.
///
/// WHY IT CAN NEVER DESCRIBE A BLOCK WITH NO TAPS
/// "No taps, no sheet" is a ratified decision: a block that ran clean must not
/// end with something to dismiss. That rule is enforced here, by the type,
/// rather than at each of the places one of these is made or presented. The
/// initialiser is *failable* — it returns nothing at all when handed an empty
/// list — so `pendingReflection == nil` and "there was nothing to ask about"
/// are the same fact, and no caller can produce an empty sheet even by mistake.
///
/// WHY IT IS `Identifiable`
/// So the screen can present it with SwiftUI's `.sheet(item:)`, which shows one
/// sheet per distinct value. Presenting on a plain true/false flag makes it
/// possible for two sheets to be asked for at once; presenting on an item makes
/// that impossible rather than merely unlikely. The identity used is the
/// block's own — see `id`.
///
/// `Sendable` and every value a constant: like `DistractionPrompt`, this is a
/// finished copy of some facts, and a screen holding it cannot change what the
/// database believes.
struct BlockReflection: Identifiable, Equatable, Sendable {
  // MARK: What the sheet is about

  /// The identity of the block that just ended — the same `sessionID` the taps
  /// carry and the same value the finished-block row is written under.
  ///
  /// Using the block's identity rather than a fresh one means asking for the
  /// same block's sheet twice is asking for the same sheet, which is what
  /// `.sheet(item:)` needs in order to refuse to present it twice.
  let id: UUID

  /// The taps recorded during that block, oldest first. **Never empty.**
  let prompts: [DistractionPrompt]

  // MARK: Initialisation

  /// Describes a finished block that has something to ask about, or nothing at
  /// all if it has not.
  ///
  /// Returning `nil` for an empty list is the whole safety property of this
  /// type: a caller writes `pendingReflection = BlockReflection(...)` and the
  /// "no taps, no sheet" rule holds automatically, with no condition anybody
  /// has to remember to write.
  ///
  /// - Parameters:
  ///   - sessionID: the identity of the block that ended.
  ///   - prompts: the taps recorded during it, oldest first.
  /// - Returns: a reflection, or `nil` when there were no taps to ask about.
  init?(sessionID: UUID, prompts: [DistractionPrompt]) {
    guard !prompts.isEmpty else { return nil }
    id = sessionID
    self.prompts = prompts
  }

  /// Describes a finished block when there is already a tap in hand.
  ///
  /// The same type, built the other way round: instead of accepting a list that
  /// might be empty and answering `nil`, this takes the first tap *separately*
  /// from the rest, so a list with nothing in it cannot even be expressed.
  /// Nothing to check, nothing to unwrap, and the same guarantee.
  ///
  /// It exists for the screens and their previews, which always have real taps
  /// to show and would otherwise have to unwrap an optional they know is there —
  /// and the usual way people do that is a force unwrap, which is banned in this
  /// codebase for good reasons. Making the honest route the convenient one is
  /// cheaper than policing the dishonest one.
  ///
  /// - Parameters:
  ///   - sessionID: the identity of the block that ended.
  ///   - firstPrompt: the first tap. Its presence is what makes the list
  ///     non-empty.
  ///   - rest: any further taps, in order after the first.
  init(sessionID: UUID, firstPrompt: DistractionPrompt, rest: [DistractionPrompt] = []) {
    id = sessionID
    prompts = [firstPrompt] + rest
  }
}
