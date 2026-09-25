import Foundation
import SwiftData

/// Everything the shape sheet does that is not drawing.
///
/// **A separate type so that "a control writes nothing" is a claim a test can make.** There is no
/// UI test target in this project, so a rule expressed only inside a `View` body is a rule nothing
/// checks. Pulled out here, the whole write surface of the screen is three methods over two stores,
/// and a test can move a control and then read `AppSettings` back to see that it did not move too.
///
/// **Ruling B, mechanically:** `remember(preset:endsWithLongBreak:)` is what a control calls and it
/// touches only the shape store; `saveToSettings(_:)` is what the one deliberate press calls and it
/// is the only thing in this feature that writes `AppSettings`. `F8-M9` is the mutation that proves
/// the separation is real rather than tidy.
///
/// **IT NOW WRITES THE SHAPE ITSELF, AND IT DID NOT BEFORE.** This comment used to read *"it never
/// calls `ShapeStore.start(_:)` — nothing on this screen runs a sprint, `F8-T4` owns that."* `T4` is
/// what is being built, and note 1 from use put the write here: *"idle should update when the sprint
/// is fitted."* The half of that sentence the old comment got right is still true and still enforced
/// one layer up — **nothing on this screen starts a timer**, and `TimerView.openShape()` refuses to
/// present the sheet at all while a block runs, so a shape can still not be written under a sprint
/// that is already going.
@MainActor
struct ShapeSheetActions {
  /// Where the two remembered controls live. Shipped in `T2`; `D32`.
  let store: ShapeStore

  /// The settings row, or `nil` when this screen is being looked at with no database behind it.
  let settings: AppSettings?

  /// The controls as they were left last time, with the store's own defaults when there is nothing
  /// stored — which is what a first run is.
  var remembered: (preset: AbsorptionPreset, endsWithLongBreak: Bool) {
    let stored = store.load()
    return (stored?.preset ?? .balanced, stored?.endsWithLongBreak ?? true)
  }

  /// The settings the shape is fitted to, or `nil` when there is no settings row to fit it to.
  ///
  /// **This screen genuinely does have to read the six values, and `TimerView`'s own standing note
  /// says not to.** That note is about two surfaces drawing the same countdown from two sources; the
  /// disagreement it guards against cannot arise here, because this screen draws no countdown and
  /// the engine publishes only `pomodorosPerSprint`. The divergence is stated rather than slipped
  /// past.
  var snapshot: TimerSettingsSnapshot? {
    settings.map(TimerSettingsSnapshot.init(clamping:))
  }

  /// A control moved. **Remembers it, and writes nothing else — least of all `AppSettings`.**
  ///
  /// The run slot is carried across untouched. Nesting the controls inside the run would make
  /// forgetting them the default behaviour of clearing it; keeping them beside it means a save
  /// here has to preserve it explicitly, which is what this line is.
  func remember(preset: AbsorptionPreset, endsWithLongBreak: Bool) {
    store.save(
      StoredShape(preset: preset, endsWithLongBreak: endsWithLongBreak, run: store.load()?.run))
  }

  /// **A shape was fitted: write it, and tell the caller so the idle timer can say the new number.**
  ///
  /// Note 1 from use, ruled 2026-09-25. The trigger is *fitting* — a control moved and the shaper
  /// produced an answer for the new budget — and not starting, not saving, and not the next block
  /// boundary.
  ///
  /// **Called on a control moving and never on the screen opening**, which is the difference between
  /// remembering a decision and overwriting one. The sheet opens on a sixty-minute budget by design
  /// (the owner confirmed that on the device, 2026-09-25), so a fit on open would replace a
  /// fifteen-minute shape somebody set yesterday with an hour they never asked for, just for looking.
  ///
  /// - Returns: `false` when there is no shape to write — *nothing fits* at this budget. **The stored
  ///   shape is then left exactly as it was**, because a budget that produced no answer has not
  ///   replaced anything; the screen already says so in its own words.
  @discardableResult
  func fit(_ shape: SprintShape?) -> Bool {
    guard let shape else { return false }
    store.start(shape)
    return true
  }

  /// The one deliberate press. Copies this shape's block lengths into the settings row.
  ///
  /// Clamped through `SettingsBounds`, so a shape whose blocks fall outside what the settings screen
  /// can offer cannot put a value in the database that no control could ever show or correct.
  ///
  /// - Returns: `false` when there is no settings row to write to, so the screen can say so rather
  ///   than draw a confirmation for a write that did not happen.
  @discardableResult
  func saveToSettings(_ write: ShapeScreenModel.SettingsWrite) -> Bool {
    guard let settings else { return false }
    settings.workMinutes = SettingsBounds.minutes.clamping(write.workMinutes)
    if let short = write.shortBreakMinutes {
      settings.shortBreakMinutes = SettingsBounds.minutes.clamping(short)
    }
    if let long = write.longBreakMinutes {
      settings.longBreakMinutes = SettingsBounds.minutes.clamping(long)
    }
    return true
  }
}
