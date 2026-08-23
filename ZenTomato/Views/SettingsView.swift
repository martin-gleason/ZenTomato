import SwiftData
import SwiftUI

/// The six values the timer runs on, and nothing else.
///
/// WHAT IS DELIBERATELY NOT HERE
/// There is no theme, no appearance switch, no music toggle, no seventh anything.
/// The spec's list of what this timer may be customised with is six items long
/// and ends with the words "Nothing else." This screen is that list.
///
/// **There is no text field on this screen, and there never may be.** Not for the
/// block lengths, not for anything. The app has a standing rule that it never
/// accepts typed input — it is not a place you write things down — and the only
/// writable screen in the app is the obvious place for that rule to be broken by
/// accident. Every value here is a stepper or a switch.
///
/// **There is no Cancel button either, and that is a decision.** Cancel implies a
/// transaction to roll back and there is not one: six independent values, each
/// showing its current state, each changed by a deliberate tap. Every change is
/// saved the moment it is made. Done and swiping the sheet away are the same
/// action, which is why the sheet is allowed to be swiped away. The undo for
/// "I set the focus block to 90 by mistake" is to set it back.
struct SettingsView: View {
  // MARK: Internal

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
              .accessibilityHint(Text("Closes settings."))
          }
        }
    }
  }

  // MARK: Private

  /// The settings row. One row by design; see `AppSettings`.
  @Query private var settings: [AppSettings]

  /// The running timer, if there is one.
  ///
  /// Optional so that this screen can be looked at in a preview with no engine
  /// behind it. In the app there is always one.
  @Environment(TimerEngine.self) private var engine: TimerEngine?

  @Environment(\.dismiss) private var dismiss

  @ViewBuilder
  private var content: some View {
    if let row = settings.first {
      SettingsForm(settings: row, isBlockRunning: engine?.isRunning == true)
    } else {
      // The same situation the timer screen draws as dashes: the database opened
      // and holds nothing. There is no row to edit, so there is nothing to show
      // and nothing to guess at.
      StoreUnavailableView(technicalDetail: "The settings row is missing.")
    }
  }
}

// MARK: - SettingsForm

/// The form itself, drawn from a settings row and one fact about the timer.
///
/// Split out so that every state of it — including the note that only appears
/// while a block is running — can be looked at in a preview without a timer.
private struct SettingsForm: View {
  // MARK: Internal

  /// The row being edited. `@Bindable` is what lets a stepper write straight into
  /// the database: there is no separate copy of these values held anywhere, so
  /// there is nothing that can be out of step with what is saved.
  @Bindable var settings: AppSettings

  /// Whether a block is running right now. Decides whether the note at the top of
  /// the form appears.
  let isBlockRunning: Bool

  var body: some View {
    Form {
      if isBlockRunning {
        runningBlockNote
      }
      blockLengths
      sprint
      whenABlockEnds
    }
    // iOS's own grouped-list background is a grey that fights this app's warm
    // page. Dropping it and painting the page underneath is what makes the sheet
    // look like part of the same app as the timer.
    .scrollContentBackground(.hidden)
    .background(Color(.surfacePrimary).ignoresSafeArea())
  }

  // MARK: Private

  /// A statement of fact, pinned above everything else because it has to be read
  /// *before* a number is changed rather than after.
  ///
  /// **This is the one amber thing on the screen.** The design system's rule is
  /// that amber marks exactly one thing at a time, and this is what it is spent
  /// on here. It is not a control: no chevron, no tap target, nothing to press.
  /// It disappears the moment the block ends, including while the sheet is open,
  /// which is slightly startling and still correct — nothing else on the screen
  /// moves when it goes.
  private var runningBlockNote: some View {
    Section {
      Label {
        Text("A block is running. Changes take effect when it ends, not now.")
          .font(Typography.label)
          .foregroundStyle(Color(.warningText))
      } icon: {
        Image(systemName: "clock")
          .foregroundStyle(Color(.warningText))
      }
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  private var blockLengths: some View {
    Section {
      minutesRow("Focus block", value: $settings.workMinutes)
      minutesRow("Short break", value: $settings.shortBreakMinutes)
      minutesRow("Long break", value: $settings.longBreakMinutes)
    } header: {
      header("Block lengths")
    } footer: {
      footer(
        """
        One minute is a real setting. It's there so you can watch a whole sprint \
        run in a few minutes instead of a few hours.
        """)
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  private var sprint: some View {
    Section {
      Stepper(value: $settings.pomodorosPerSprint, in: SettingsBounds.pomodorosPerSprint) {
        row("Pomodoros per sprint", value: Self.spokenPomodoros(settings.pomodorosPerSprint))
      }
      .accessibilityValue(Text(Self.spokenPomodoros(settings.pomodorosPerSprint)))
      .accessibilityHint(Text("How many focus blocks before the long break."))
    } header: {
      header("Sprint")
    } footer: {
      footer("How many focus blocks you do before the long break.")
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  private var whenABlockEnds: some View {
    Section {
      // Tinted from the design system rather than left as the system's green.
      // The two look almost identical, which is exactly why it has to be said:
      // an untinted switch is the app's one colour arriving from somewhere other
      // than the token table.
      Toggle("Sound", isOn: $settings.soundEnabled)
        .tint(Color(.action))
        // The visible label is one word because the section heading above it
        // supplies the rest of the sentence. VoiceOver does not read a section
        // heading before every row, so it gets the whole phrase.
        .accessibilityLabel(Text("Sound when a block ends"))

      Toggle("Start the next block automatically", isOn: $settings.autoStartNextBlock)
        .tint(Color(.action))
        .accessibilityHint(
          Text("When the long break ends the timer stops and waits, even with this on."))
    } header: {
      header("When a block ends")
    } footer: {
      footer(
        """
        With Sound off the block still ends on time and the alert still appears — \
        the phone just doesn't make a noise.

        Auto-start carries you through a sprint, not into the next one. When the \
        long break ends the timer stops and waits for you.
        """)
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  /// One duration row.
  ///
  /// **The bounds are the control, not a check afterwards.** A stepper that stops
  /// at 1 and at 120 cannot produce a number outside them, so there is no
  /// validation code on this screen, no error state to design, and no alert copy
  /// to write. The upper bound exists so a mis-set value cannot schedule an alarm
  /// days away; the lower one is what makes a whole sprint testable by hand in
  /// eight minutes instead of two hours.
  private func minutesRow(_ title: String, value: Binding<Int>) -> some View {
    Stepper(value: value, in: SettingsBounds.minutes) {
      row(title, value: "\(value.wrappedValue) min")
    }
    // Drawn short, spoken in full: the eye wants the abbreviation and the ear
    // wants the word.
    .accessibilityValue(Text(Self.spokenMinutes(value.wrappedValue)))
  }

  /// A row's label on the left and its current value on the right, which is iOS's
  /// own convention for a settings row.
  private func row(_ title: String, value: String) -> some View {
    HStack {
      Text(title)
        .font(Typography.body)
        .foregroundStyle(Color(.textPrimary))
      Spacer(minLength: Spacing.sm)
      Text(value)
        .font(Typography.body)
        .foregroundStyle(Color(.textMuted))
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

  private static func spokenMinutes(_ minutes: Int) -> String {
    "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
  }

  /// The singular is not cosmetic. A sprint of one pomodoro is a real setting —
  /// it is the documented edge case where every focus block is followed by a long
  /// break and no short break ever happens — so "1 pomodoros" would appear on the
  /// very screen that sets it.
  private static func spokenPomodoros(_ count: Int) -> String {
    "\(count) \(count == 1 ? "pomodoro" : "pomodoros")"
  }
}

// MARK: - Previews

#Preview("Light") {
  SettingsPreviewHost(appearance: .light)
}

#Preview("Dark") {
  SettingsPreviewHost(appearance: .dark)
}

/// While a block is running, with the amber note at the top.
#Preview("Block running") {
  SettingsPreviewHost(appearance: .light, isBlockRunning: true)
}

/// The singular value string. A sprint of one is a real setting.
#Preview("Sprint of one") {
  SettingsPreviewHost(appearance: .light, pomodorosPerSprint: 1)
}

/// The largest text size iOS offers. Nothing may be clipped; rows grow instead.
#Preview("Largest text") {
  SettingsPreviewHost(appearance: .light)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships. It opens a throwaway store that
/// lives in memory only, so no preview can touch the real one.
private struct SettingsPreviewHost: View {
  // MARK: Lifecycle

  init(appearance: ColorScheme, isBlockRunning: Bool = false, pomodorosPerSprint: Int = 4) {
    self.appearance = appearance
    self.isBlockRunning = isBlockRunning
    _store = State(initialValue: Result {
      let container = try AppModelContainer.make(.inMemory)
      let row = try AppSettings.current(in: container.mainContext)
      row.pomodorosPerSprint = pomodorosPerSprint
      return PreviewStore(container: container, row: row)
    })
  }

  // MARK: Internal

  var body: some View {
    switch store {
    case .success(let opened):
      NavigationStack {
        SettingsForm(settings: opened.row, isBlockRunning: isBlockRunning)
          .navigationTitle("Settings")
          .navigationBarTitleDisplayMode(.inline)
      }
      .modelContainer(opened.container)
      .preferredColorScheme(appearance)

    case .failure(let error):
      StoreUnavailableView(technicalDetail: error.localizedDescription)
    }
  }

  // MARK: Private

  /// An open throwaway store and the one settings row inside it.
  private struct PreviewStore {
    let container: ModelContainer
    let row: AppSettings
  }

  private let appearance: ColorScheme
  private let isBlockRunning: Bool

  /// Held as state so the throwaway store is opened once per preview rather than
  /// every time the canvas redraws.
  @State private var store: Result<PreviewStore, any Error>
}
