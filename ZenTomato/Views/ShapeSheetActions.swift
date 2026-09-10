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
/// **It never calls `ShapeStore.start(_:)`.** Nothing on this screen runs a sprint — `F8-T4` owns
/// that — so the single stored run slot is not written here at all, and a shape cannot be
/// overwritten under a sprint that is already going.
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
