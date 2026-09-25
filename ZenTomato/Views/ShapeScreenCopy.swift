import Foundation

/// Every sentence the "fit a sprint" screen says, in one place.
///
/// **A seam, not a filing cabinet** — the same one `StatsScreenCopy` is. What the screen *computes*
/// and what it *says* change at different rates and are reviewed by different eyes: the owner reads
/// the words, and the words are the half of this feature that makes a claim about somebody's day.
///
/// Two rules run through all of it.
///
/// **A statement of fact, never a verdict.** Neither of the two hard states may console, praise, or
/// suggest what to do with the time. The under-the-minimum line is arithmetic and nothing else; the
/// nothing-fits line is a claim about the **budget**, never about the person. No "only", no "just",
/// no exclamation mark, and no comparison with yesterday.
///
/// **Every number in here is passed in, never typed in.** The suggested minimum and the shortest
/// workable budget both move with the trailing-long-break toggle — see `ShapeBudgets` — so a
/// hardcoded sixty or fifteen would be a sentence the shape directly above it contradicts.
extension ShapeScreenModel {
  // MARK: The screen, and its controls

  /// The budget the screen opens on, and the one number here that is not copy.
  ///
  /// **One hour, which is four cycles.** A cycle is a pomodoro plus the break that follows it
  /// (`docs/specs/definitions.md`), and at sixty minutes the shaper produces exactly four of them —
  /// `10·5·10·5·10·5·10` with a five-minute long break, forty minutes of focus. The owner confirmed
  /// this as the default on 2026-09-24: *"set the default as a traditional 1 hour, 4 cycle sprint."*
  ///
  /// **It is NOT a traditional 25-minute pomodoro, and the difference is worth knowing.** Four
  /// traditional poms need 130 minutes; at sixty the shaper squeezes each to its ten-minute floor.
  /// What the default is traditional about is the *rhythm* — four cycles, ending on a long break —
  /// not the block length. `ShapeDefaultTests` pins both halves so neither drifts.
  ///
  /// Named here rather than left as a literal in `ShapeSheet`'s `@State`, so that the screen and the
  /// test that guards it read the same number instead of agreeing by coincidence.
  static let defaultBudgetMinutes = 60

  static let title = "Fit a sprint"

  /// The one question this screen asks. **It asks for a duration and never for a task**: the
  /// control is a list of legal minutes, so there is nothing here to type into.
  static let durationLabel = "How long have you got?"
  static let durationHint = "The shape below is fitted to this."

  /// The absorption control. **The words "preset" and "absorption" are never shown to a reader** —
  /// neither is in `docs/specs/definitions.md`, and the second is engine vocabulary.
  static let spareMinutesLabel = "Spare minutes"
  static let spareMinutesFooter = "Where the minutes that don't divide evenly go."

  static let longBreakLabel = "End with a long break"

  /// The honest framing: the toggle does not buy time, it moves it.
  static let longBreakFooter = """
    The long break a finished sprint earns, taken out of the time you have. With it off, that time \
    goes to the pomodoros and their short breaks instead.
    """

  static let shapeHeader = "The shape"

  // MARK: Save to settings

  static let saveLabel = "Save to settings"

  /// **The second sentence is Ruling B said out loud**, and it is the one that makes a deliberate
  /// press feel safe rather than mysterious.
  ///
  /// Not worded as "Save shape": a saved, named shape is outside this feature's scope fence, and a
  /// button that sounds like it does that will be asked to.
  static let saveHint = """
    Makes these block lengths your defaults for every sprint. Leaving this screen without pressing \
    it changes nothing.
    """

  static let saved = "Saved."

  // MARK: The two honest states

  /// The nothing-fits heading. The same register as `StatsScreenCopy.emptyHeading`: a fact about
  /// the number that was chosen, not a claim about the person or about the app.
  ///
  /// **No red, no icon, no "Error", and no "couldn't".** "Couldn't" is reserved in this codebase for
  /// claims about the app, and this is not one — the calculator worked perfectly and the answer is
  /// that fourteen minutes is fourteen minutes.
  static let nothingFitsHeading = "No shape this short"

  /// The nothing-fits body. The number moves with the toggle, so it is never fifteen by assumption.
  ///
  /// **It says what a cycle is, and then where to go instead** — the owner's wording, `O38`. Two
  /// things made that worth adding. A reader told only that nothing fits does not know WHY fifteen
  /// minutes is the floor, and the reason is that a cycle is a pomodoro *and* the break after it, so
  /// the budget has to cover both. And this screen's floors are not the app's: `SettingsBounds`
  /// allows any block from **1 to 120 minutes**, so a shorter sprint is entirely possible — just not
  /// through this screen. Sending somebody to Settings is a fact, not a consolation.
  ///
  /// **`cycle` is the ratified word for a pom plus its break** (`docs/specs/definitions.md`, 2026-09-09),
  /// and the reason it exists is so this screen can explain itself "without taking *pomodoro*'s name
  /// for it, and without the app teaching a definition the method does not hold."
  static func nothingFitsBody(shortestMinutes: Int?) -> String {
    guard let shortestMinutes else {
      return """
        These settings can't make a shape of any length. You can set the block lengths \
        yourself in Settings.
        """
    }
    return """
      The shortest shape these controls can make is \
      \(StatsWords.count(shortestMinutes, "minute", "minutes")). A cycle is one pomodoro plus \
      the break that follows it, and the time has to cover both. For anything shorter, set the \
      block lengths yourself in Settings.
      """
  }

  /// Under the suggested minimum: arithmetic, and then the one thing a reader can act on.
  ///
  /// *"45 minutes fits 3 pomodoros. A full sprint needs 60 minutes."* Both numbers are computed. The
  /// shape still runs — this is a warning, not an error — so nothing on the screen is switched off
  /// and no colour role but `textMuted` is used to draw it.
  ///
  /// **The third sentence exists because the first two read as a refusal and this state is not one**
  /// (`O38`). It says the shape runs, and it points at `saveLabel` — which is on this screen already,
  /// in this state, because `saveDetail` is non-nil whenever a shape exists. An earlier draft sent
  /// the reader to the Settings menu instead; that would have walked them past a button doing exactly
  /// what they were being sent to do.
  ///
  /// It does not breach the no-suggestions rule at the top of this file. That rule forbids suggesting
  /// **what to do with the time**; this is about where the block lengths are kept.
  static func underMinimum(budgetMinutes: Int, fits pomCount: Int, fullSprintNeeds minutes: Int) -> String {
    """
    \(StatsWords.count(budgetMinutes, "minute", "minutes")) fits \
    \(StatsWords.count(pomCount, "pomodoro", "pomodoros")). A full sprint needs \
    \(StatsWords.count(minutes, "minute", "minutes")). This shape still runs — \(saveLabel) makes it \
    your default.
    """
  }

  // MARK: Saying the numbers

  /// The name a reader hears for a block. "Pomodoro", not `BlockKind.displayName`'s "Focus".
  static func name(for kind: BlockKind) -> String {
    switch kind {
    case .work: "Pomodoro"
    case .shortBreak: "Short break"
    case .longBreak: "Long break"
    }
  }

  /// The one line above the blocks: what this shape is, in the order that matters.
  ///
  /// Pomodoros first, because that is what the log counts.
  var summaryLine: String? {
    guard let pomCount, let focusMinutes, let finishTime else { return nil }
    return """
      \(StatsWords.count(pomCount, "pomodoro", "pomodoros")), \
      \(StatsWords.count(focusMinutes, "minute", "minutes")) of focus, finishing at \(finishTime).
      """
  }

  /// What VoiceOver reads for the finish time, which a bare clock reading does not explain.
  var spokenFinishTime: String? {
    finishTime.map { "Finishes at \($0)" }
  }

  /// Exactly what **Save to settings** will put into `AppSettings`, in the same values it writes.
  ///
  /// **A secondary artefact gets the same treatment as the primary one.** The settings write is a
  /// thing this screen produces and a person is asked to trust, so it is described by a sentence
  /// built from the value that is written rather than from the model that generated it.
  var saveDetail: String? {
    guard let write = settingsWrite else { return nil }
    var parts = ["focus blocks to \(write.workMinutes) min"]
    if let short = write.shortBreakMinutes { parts.append("short breaks to \(short) min") }
    if let long = write.longBreakMinutes { parts.append("the long break to \(long) min") }
    let list = parts.formatted(.list(type: .and))
    let caveat = pomodorosDiffer
      ? " This shape's pomodoros aren't all the same length; the first one's length is what's written."
      : ""
    return "Sets \(list).\(caveat)"
  }
}
