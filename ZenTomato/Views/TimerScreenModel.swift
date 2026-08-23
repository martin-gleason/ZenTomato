import Foundation

/// Everything the timer screen draws, as plain values.
///
/// WHY THE SCREEN IS SPLIT IN TWO, FOR A READER WHO DOES NOT WRITE SWIFT
/// `TimerView` is the screen as it appears in the running app: it talks to the
/// timer engine, presents the settings sheet, and refreshes once a second.
/// `TimerScreen` is the same picture with nothing behind it — handed a small bag
/// of finished strings and numbers, which it draws. This type is that bag.
///
/// The split buys one thing and it is worth the extra file: **every state of the
/// timer screen can be looked at without a running timer.** A focus block half
/// way through, a sprint that has just finished, a database with no settings in
/// it — each is a few lines in a preview rather than a sequence of taps on a
/// phone, and none of them has to wait for a real twenty-five minutes to pass.
struct TimerScreenModel {
  // MARK: Nested types

  /// Which controls are at the bottom of the screen.
  enum Controls {
    /// One filled button.
    ///
    /// `spokenLabel` is the longer sentence VoiceOver reads — "Start focus block,
    /// 25 minutes" — while the drawn glyphs stay at "Start". The split is
    /// deliberate: repeating the block name inside the button buys nothing on
    /// screen, where the word above and the number below already say it, and it
    /// costs width at the largest text sizes. VoiceOver reads elements one at a
    /// time and so does need the whole sentence.
    case start(isEnabled: Bool, spokenLabel: String)

    /// One quiet, unfilled Stop.
    ///
    /// There was a Skip button beside it and D13 removed it: an exit that costs
    /// a single tap is not an exit from a focus block, it is a way of not having
    /// one. Nothing filled is drawn while a block runs, because while a focus
    /// block runs the thing to do is nothing.
    case running
  }

  /// How many pomodoros of the sprint are finished, out of how many.
  struct Progress {
    let completed: Int
    let total: Int
  }

  /// The two capture buttons, and what each of them has counted so far in the
  /// block running now.
  ///
  /// **`nil` is the whole point of this type.** "Are the capture buttons on the
  /// screen?" is expressed as whether there is a value here at all, rather than
  /// as a condition somebody has to remember to write inside a view. A
  /// distraction during a break is not a distraction, so there is no value
  /// during a break — and the buttons therefore cannot be drawn, cannot be
  /// tapped, and cannot be reached by VoiceOver or Voice Control.
  ///
  /// This is the first of two guards and it is the one a person sees. The
  /// second lives in the timer engine, which refuses to write a row that does
  /// not belong to a running focus block whoever asks it to. Both exist on
  /// purpose: this one is what the screen looks like, and that one is what makes
  /// it true for any future caller.
  struct Capture {
    let internalCount: Int
    let externalCount: Int

    /// The capture buttons for a block, or `nil` if there should not be any.
    ///
    /// A pure function of three finished values, which is what lets the rule be
    /// tested without a database, a timer or a screen — see
    /// `DistractionScreenModelTests`.
    ///
    /// - Parameters:
    ///   - isRunning: whether any block is counting at all.
    ///   - kind: which kind of block that is.
    ///   - taps: the kinds recorded in this block so far, in any order. Only
    ///     their number matters here; the tally line on the sheets is what reads
    ///     them properly.
    static func forBlock(isRunning: Bool, kind: BlockKind, taps: [DistractionKind]) -> Capture? {
      guard isRunning, kind == .work else { return nil }
      return Capture(
        internalCount: taps.filter { $0 == .internalInterruption }.count,
        externalCount: taps.filter { $0 == .externalInterruption }.count)
    }
  }

  /// The line above the block name saying what this pomodoro is attached to.
  ///
  /// **`nil` is a state of its own and it means "there is no Todoist here".**
  /// With no token stored the line is absent entirely — nothing nags, and the
  /// timer is exactly the screen F2 shipped. It is present in both signed-in
  /// states, with a plan and without one, so the countdown does not move as a
  /// plan empties.
  struct Attachment: Equatable {
    /// The whole line, already assembled. **One `Text`, never two elements side
    /// by side** — a two-element layout has to be re-solved at every text size
    /// and eventually truncates, and a truncated task title is a wrong record
    /// on screen. The middle dot is the app's existing idiom.
    let line: String

    /// Whether the line is a control.
    ///
    /// **Tappable when idle or on a break; inert text during a focus block.**
    /// The attachment was frozen at Start, and any distraction already written
    /// to this block names the task it started with — so letting it change
    /// mid-block would put two different task names on one block's records.
    let isTappable: Bool

    /// What the line says, given where the timer is and what the plan holds.
    ///
    /// A pure function of five finished facts, which is what lets every state
    /// of it be tested with no database, no timer and no screen.
    ///
    /// - Parameters:
    ///   - hasToken: whether Todoist is connected at all.
    ///   - isFocusRunning: whether a focus block is counting right now.
    ///   - runningBlock: what the timer recorded this block as attached to.
    ///     **Read from what the timer wrote, never guessed from the plan's
    ///     cursor** — the cursor cannot tell the last item having been handed
    ///     out from the plan having run out.
    ///   - runningBlockIsGone: whether that task has left Todoist. `false` when
    ///     it is there, and also when the mirror has never been filled — absent
    ///     from an empty mirror is not evidence.
    ///   - nextItem: the item at the front of the queue, for the break and the
    ///     idle screen.
    static func forTimer(
      hasToken: Bool,
      isFocusRunning: Bool,
      runningBlock: SessionAttachment?,
      runningBlockIsGone: Bool = false,
      nextItem: SessionPlanStore.Item?) -> Attachment? {
      guard hasToken else { return nil }

      guard isFocusRunning else {
        guard let nextItem else { return Attachment(line: nothingAttached, isTappable: true) }
        return Attachment(line: "Next · \(nextItem.titleSnapshot)", isTappable: true)
      }

      if let taskTitle = runningBlock?.taskTitle {
        let line = runningBlockIsGone
          ? "\(taskTitle) · not in Todoist any more"
          : taskTitle
        return Attachment(line: line, isTappable: false)
      }

      if let projectTitle = runningBlock?.projectTitle {
        return Attachment(line: "Project · \(projectTitle)", isTappable: false)
      }

      return Attachment(line: nothingAttached, isTappable: false)
    }

    /// Connected, and this block has nothing of its own. A pomodoro with
    /// nothing attached is a normal pomodoro — the timer shipped and is in use
    /// without Todoist at all.
    private static let nothingAttached = "No task attached"
  }

  // MARK: Stored properties

  /// What VoiceOver calls the block: "Focus block", "Short break", "Long break".
  let blockName: String

  /// The small word above the number. Drawn in capitals.
  let kicker: String

  /// The big number, already formatted — `25:00`, `04:31`, or `--:--`.
  let numeral: String

  /// Whether the number is a real reading. When it is not, the dashes are drawn
  /// in the quietest ink, so that "there is nothing to show" reads differently
  /// from "here is your time" at a glance as well as in words.
  let numeralIsAReading: Bool

  /// The number said in words: "25 minutes", or "24 minutes 58 seconds
  /// remaining". Built from the same source as the printed one, so the two
  /// cannot disagree.
  let spokenNumeral: String

  /// The sprint rule, or `nil` to leave it out entirely.
  let progress: Progress?

  /// "Sprint complete — 4 pomodoros done.", shown while the screen sits idle
  /// after a long break.
  let completionNote: String?

  /// Shown when the last thing the timer was asked to do did not fully work —
  /// most importantly, when an alarm could not be set. An alarm that silently
  /// fails to be set is the worst bug this feature could ship, so it is said out
  /// loud on the screen rather than written to a log nobody reads.
  let failureNote: String?

  /// The capture buttons, or `nil` when there must not be any. See `Capture`.
  let capture: Capture?

  /// What this pomodoro is attached to, or `nil` when there is no Todoist.
  let attachment: Attachment?

  let controls: Controls

  /// Whether a block is counting right now.
  ///
  /// Derived from `controls` rather than stored, so it cannot disagree with what
  /// the bottom of the screen is drawing. The screen needs it for one thing: a
  /// break running has no capture buttons but must still leave their space
  /// empty, so that the countdown does not jump the moment a focus block ends.
  var isRunning: Bool {
    if case .running = controls { return true }
    return false
  }

  // MARK: Initialisation

  /// - Parameter numeralIsAReading: `true` for every state except the one below,
  ///   which is the only one that draws something other than a time.
  init(
    blockName: String,
    kicker: String,
    numeral: String,
    numeralIsAReading: Bool = true,
    spokenNumeral: String,
    progress: Progress?,
    completionNote: String? = nil,
    failureNote: String? = nil,
    capture: Capture? = nil,
    attachment: Attachment? = nil,
    controls: Controls
  ) {
    self.blockName = blockName
    self.kicker = kicker
    self.numeral = numeral
    self.numeralIsAReading = numeralIsAReading
    self.spokenNumeral = spokenNumeral
    self.progress = progress
    self.completionNote = completionNote
    self.failureNote = failureNote
    self.capture = capture
    self.attachment = attachment
    self.controls = controls
  }

  // MARK: The one state that is not a timer

  /// The database opened but holds no settings row.
  ///
  /// Everything is unknown here, so nothing is guessed: dashes instead of a time,
  /// Start switched off because there is no length to start, and **no sprint rule
  /// at all** — the sprint's size is unknown, and an empty rule of an invented
  /// length is a guess presented as a fact.
  ///
  /// This is the one surviving reason the Start button still needs its
  /// switched-off appearance now that it is no longer permanently disabled.
  static func noSettingsRow(numeral: String) -> TimerScreenModel {
    TimerScreenModel(
      blockName: "Focus block",
      kicker: BlockKind.work.displayName,
      numeral: numeral,
      numeralIsAReading: false,
      spokenNumeral: "length not available",
      progress: nil,
      controls: .start(isEnabled: false, spokenLabel: "Start focus block"))
  }
}
