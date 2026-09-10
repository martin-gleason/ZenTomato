import SwiftData
import SwiftUI

/// *How long have you got?* — and the shape that answers it, drawn before anything starts.
///
/// **This view draws finished values and calls back out through closures**, which is what lets every
/// state of it — including both of the two hard ones — be a few lines in a preview rather than a
/// sequence of taps on a phone.
///
/// **THERE IS NO TEXT FIELD HERE AND THERE NEVER MAY BE.** The duration is a list of legal minutes,
/// so a value outside them cannot be offered, cannot be chosen and does not have to be rejected —
/// the bounds are the control, exactly as they are on the settings screen. An input that accepted
/// free text would be a capture surface wearing a different hat, on the one screen in this feature
/// where somebody is being asked to say something.
///
/// **Nothing here starts a timer and nothing here is switched off.** A shape that is short of a
/// full sprint is a real shape and it runs; the screen says so and leaves the decision alone.
struct ShapeView: View {
  // MARK: The finished values

  let model: ShapeScreenModel

  /// Every duration that may be chosen. A list, so the bounds are inside the control.
  let budgetChoices: [Int]

  /// What to say after a deliberate save, or `nil` when none has happened.
  let savedNote: String?

  // MARK: The way back out

  // `@Sendable`, because each of these becomes the setter of a `Binding` and SwiftUI's is. Marked
  // rather than worked around: the Release build treats the mismatch as a warning and this project
  // ships no warnings.
  var onBudgetChange: @Sendable (Int) -> Void = { _ in }
  var onPresetChange: @Sendable (AbsorptionPreset) -> Void = { _ in }
  var onToggleLongBreak: @Sendable (Bool) -> Void = { _ in }
  var onSaveToSettings: () -> Void = { }

  var body: some View {
    Form {
      duration
      controls
      shape
      save
    }
  }

  // MARK: Private

  private var duration: some View {
    Section {
      Picker(ShapeScreenModel.durationLabel, selection: binding(model.budgetMinutes, onBudgetChange)) {
        ForEach(budgetChoices, id: \.self) { minutes in
          // Drawn short, spoken in full: the eye wants the abbreviation and the ear wants the word.
          Text("\(minutes) min")
            .accessibilityLabel(Text(StatsWords.count(minutes, "minute", "minutes")))
            .tag(minutes)
        }
      }
      .pickerStyle(.navigationLink)
      .font(Typography.body)
      .accessibilityHint(Text(ShapeScreenModel.durationHint))
    } footer: {
      footer(ShapeScreenModel.durationHint)
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  private var controls: some View {
    Section {
      Picker(ShapeScreenModel.spareMinutesLabel, selection: binding(model.preset, onPresetChange)) {
        // The three names already exist on the model layer. Restating them here is how a preset
        // comes to be spelled two ways on one screen.
        ForEach(AbsorptionPreset.allCases, id: \.self) { preset in
          Text(preset.displayName).tag(preset)
        }
      }
      .pickerStyle(.navigationLink)
      .font(Typography.body)

      Toggle(ShapeScreenModel.longBreakLabel, isOn: binding(model.endsWithLongBreak, onToggleLongBreak))
        .font(Typography.body)
        .tint(Color(.action))
    } footer: {
      footer("\(ShapeScreenModel.spareMinutesFooter)\n\n\(ShapeScreenModel.longBreakFooter)")
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  /// The shape, or the sentence that says there is not one.
  @ViewBuilder
  private var shape: some View {
    Section {
      switch model.state {
      case .nothingFits:
        nothingFits
      case .ok, .underSuggestedMinimum:
        summary
        ForEach(model.rows) { row in
          blockRow(row)
        }
      }
    } header: {
      header(ShapeScreenModel.shapeHeader)
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  /// A fact about the budget, never a claim about the person. No red, no icon, nothing disabled.
  private var nothingFits: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      Text(ShapeScreenModel.nothingFitsHeading)
        .font(Typography.title)
        .foregroundStyle(Color(.textPrimary))
      Text(ShapeScreenModel.nothingFitsBody(shortestMinutes: model.shortestShapeMinutes))
        .font(Typography.body)
        .foregroundStyle(Color(.textMuted))
    }
    .padding(.vertical, Spacing.xxs)
  }

  @ViewBuilder
  private var summary: some View {
    if let line = model.summaryLine {
      VStack(alignment: .leading, spacing: Spacing.xs) {
        Text(line)
          .font(Typography.bodyEmphasis)
          .foregroundStyle(Color(.textPrimary))
        // The warning, not an error. `textMuted` rather than `dangerText`, which this codebase
        // reserves for a claim about the app.
        if let warning = model.underMinimumLine {
          Text(warning)
            .font(Typography.body)
            .foregroundStyle(Color(.textMuted))
        }
      }
      .padding(.vertical, Spacing.xxs)
      // One element rather than two, so the finish time is not read as a bare clock reading with
      // nothing to say what it is a time for.
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text([line, model.underMinimumLine].compactMap { $0 }.joined(separator: " ")))
    }
  }

  /// One block: what it is, and how long it runs.
  private func blockRow(_ row: ShapeScreenModel.Row) -> some View {
    HStack {
      Text(ShapeScreenModel.name(for: row.kind))
        .font(Typography.body)
        .foregroundStyle(Color(.textPrimary))
      Spacer()
      Text(row.drawn)
        .font(Typography.data)
        .foregroundStyle(Color(.textMuted))
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(row.spokenLabel))
    .accessibilityValue(Text(row.spokenValue))
  }

  @ViewBuilder
  private var save: some View {
    if let detail = model.saveDetail {
      Section {
        Button(ShapeScreenModel.saveLabel) { onSaveToSettings() }
          .font(Typography.button)
          .foregroundStyle(Color(.action))
          .accessibilityHint(Text(ShapeScreenModel.saveHint))
        if let savedNote {
          Text(savedNote)
            .font(Typography.body)
            .foregroundStyle(Color(.textMuted))
        }
      } footer: {
        footer("\(detail)\n\n\(ShapeScreenModel.saveHint)")
      }
      .listRowBackground(Color(.surfaceRaised))
    }
  }

  private func header(_ title: String) -> some View {
    Text(title)
      .font(Typography.kicker)
      .textCase(.uppercase)
      .foregroundStyle(Color(.textMuted))
  }

  private func footer(_ text: String) -> some View {
    Text(text)
      .font(Typography.body)
      .foregroundStyle(Color(.textMuted))
  }

  /// A control's two-way binding built from a finished value and the closure that reports a change.
  ///
  /// The view holds no state of its own: what is drawn is what it was handed, and a move goes
  /// straight back out to whoever owns it.
  private func binding<Value: Sendable>(
    _ value: Value, _ change: @escaping @Sendable (Value) -> Void
  ) -> Binding<Value> {
    Binding(get: { value }, set: change)
  }
}

// MARK: - The wiring

/// The screen as it appears in the running app: the two remembered controls, the settings row the
/// shape is fitted to, and the calculator.
///
/// **The only thing on this screen that touches a store.** `ShapeView` above draws and calls back;
/// everything that reads or writes anything is here or in `ShapeSheetActions`.
///
/// **`UserDefaults` is never named here.** The shape store is handed down from the composition root
/// — the one file in the app allowed to name it — and a fence asserts that the word appears nowhere
/// else.
struct ShapeSheet: View {
  /// Where the two remembered controls live. Handed down, never reached for.
  let shapes: ShapeStore

  var body: some View {
    NavigationStack {
      ShapeView(
        model: model,
        budgetChoices: Self.budgetChoices,
        savedNote: savedNote,
        // `assumeIsolated` rather than a `Task` hop, for the reason `TimerView` gives at the music
        // switch: SwiftUI calls a `Binding` setter on the main actor, so this asserts something
        // already true instead of deferring the control by a run-loop turn.
        onBudgetChange: { minutes in MainActor.assumeIsolated { budgetMinutes = minutes; savedNote = nil } },
        onPresetChange: { chosen in MainActor.assumeIsolated { preset = chosen; changed() } },
        onToggleLongBreak: { isOn in MainActor.assumeIsolated { endsWithLongBreak = isOn; changed() } },
        onSaveToSettings: { saveToSettings() })
        .navigationTitle(ShapeScreenModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
              .accessibilityHint(Text("Closes this screen. Nothing here has started a timer."))
          }
        }
    }
    // Read once when the screen opens, not on every redraw: these are the controls as they were
    // left last time, and re-reading them under a finger would fight the person moving them.
    .task {
      let remembered = actions.remembered
      preset = remembered.preset
      endsWithLongBreak = remembered.endsWithLongBreak
    }
  }

  // MARK: Private

  /// Every duration this screen offers, in five-minute steps.
  ///
  /// The bottom of the range is below the shortest shape on purpose: *nothing fits* is a state
  /// somebody has to be able to reach, or the sentence that handles it is never seen.
  private static let budgetChoices = Array(stride(from: 5, through: 240, by: 5))

  @Environment(\.dismiss) private var dismiss

  /// The settings row. One row by design; see `AppSettings`.
  @Query private var settings: [AppSettings]

  @State private var budgetMinutes = 60
  @State private var preset: AbsorptionPreset = .balanced
  @State private var endsWithLongBreak = true
  @State private var savedNote: String?

  private var actions: ShapeSheetActions {
    ShapeSheetActions(store: shapes, settings: settings.first)
  }

  /// The shape, and the two budgets the honest sentences quote.
  ///
  /// **`SprintShaper` is asked afresh on every change**, which is what makes the effect of a control
  /// visible in the numbers rather than described in a footnote. With no settings row there is
  /// nothing to fit a shape to, so the answer is the same `nil` the calculator gives — the screen
  /// says "no shape this short" rather than drawing an empty one.
  private var model: ShapeScreenModel {
    guard let snapshot = actions.snapshot else {
      return ShapeScreenModel(
        budgetMinutes: budgetMinutes, preset: preset, endsWithLongBreak: endsWithLongBreak, shape: nil)
    }
    return .forControls(
      budgetMinutes: budgetMinutes,
      preset: preset,
      endsWithLongBreak: endsWithLongBreak,
      settings: snapshot,
      startingAt: Date())
  }

  /// A control moved. The controls are remembered; nothing else is written.
  private func changed() {
    savedNote = nil
    remember()
  }

  /// Remembers the two controls. **Writes to the shape store and to nothing else.**
  private func remember() {
    actions.remember(preset: preset, endsWithLongBreak: endsWithLongBreak)
  }

  /// The one deliberate press in this feature that writes `AppSettings`.
  private func saveToSettings() {
    guard let write = model.settingsWrite else { return }
    savedNote = actions.saveToSettings(write) ? ShapeScreenModel.saved : nil
  }
}
