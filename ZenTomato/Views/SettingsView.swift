import SwiftData
import SwiftUI

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation and previews. This screen is the one place
// in the app where a rule is stated as a prohibition — there is no text field
// here and there never may be — so the reasoning sits beside every row, and the
// new Todoist section carries the sign-out semantics in full because they are
// the part somebody will check. The same exemption is already taken by
// `TimerScreen.swift`.

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
/// accident. Every value here is a list you pick from or a switch you flip.
///
/// **There is no Cancel button either, and that is a decision.** Cancel implies a
/// transaction to roll back and there is not one: six independent values, each
/// showing its current state, each changed by a deliberate tap. Every change is
/// saved the moment it is made. Done and swiping the sheet away are the same
/// action, which is why the sheet is allowed to be swiped away. The undo for
/// "I set the focus block to 90 by mistake" is to set it back.
struct SettingsView: View {
  // MARK: Internal

  /// Where the Todoist credential lives.
  let tokens: any TokenStore

  /// The local mirror of Todoist. Emptied by signing out.
  let cache: TodoistCacheStore

  /// The session plan. Emptied by signing out.
  let plan: SessionPlanStore

  /// Asks the world again whether music can be played.
  ///
  /// **Settings is now advertised as the fast way to answer `O14`, so it must not
  /// answer it from memory.** Availability is read at launch and would otherwise
  /// stay whatever it was then — somebody who grants permission in iOS Settings
  /// and comes straight back here would read the old answer and conclude the app
  /// is broken. The music picker already refreshes on appear for exactly this
  /// reason; this is the same call from the other screen.
  let refreshMusicAvailability: () -> Void

  /// Whether Apple Music can actually be used, read live from the coordinator.
  ///
  /// **Shown here rather than only in the music picker, and that is the whole of
  /// this change.** The state was drawn as a footer *beneath the library list* —
  /// so on an account with a lot of playlists it sat behind two minutes of
  /// scrolling, which is the same as not being there. A person wondering whether
  /// this app can see their subscription looks in Settings, where this app
  /// already keeps the other service's state.
  let musicAvailability: MusicAvailability

  /// Removes the credential, this app's copy of Todoist, and the session plan.
  ///
  /// **Every record of a task this app completed is kept.** Those rows are this
  /// app's own history rather than a copy of somebody else's data, and throwing
  /// them away because a connection was ended would destroy the one thing this
  /// feature produces that Todoist cannot hand back offline.
  ///
  /// This is also the **only** thing that empties the mirror and the plan. A
  /// token that stopped being accepted clears the credential and nothing else:
  /// that is Todoist's act, not a decision to disconnect, and throwing away a
  /// half-worked plan because a credential went stale would be a punishment for
  /// something nobody did.
  ///
  /// It is a function on the screen rather than a method on the form so that it
  /// can be exercised without a screen — signing out touches three separate
  /// stores, and "which of them did it miss?" is exactly the question a test
  /// should be able to ask.
  ///
  /// **EACH STORE IS ATTEMPTED ON ITS OWN.** They were once in a single `do`,
  /// which meant a Keychain that refused to delete stopped the mirror being
  /// emptied — the credential still on the phone, a full copy of somebody's
  /// Todoist still on the phone, the plan gone anyway, and a row reading
  /// "Couldn't sign out". Of the three things this removes, the one with a
  /// security meaning was the one left behind, and the dialog had already
  /// promised all three. Three independent attempts cannot do that: one refusal
  /// is one thing left, and it is reported.
  ///
  /// - Returns: `true` when all three were emptied.
  @MainActor
  @discardableResult
  static func signOutOfTodoist(
    tokens: any TokenStore,
    cache: TodoistCacheStore?,
    plan: SessionPlanStore?) -> Bool {
    var everything = true
    do {
      try cache?.clear()
    } catch {
      everything = false
    }
    if plan?.clear() == false { everything = false }
    // The credential last, so a refusal here is reported against a phone where
    // everything else has already gone.
    do {
      try tokens.clear()
    } catch {
      everything = false
    }
    return everything
  }

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
      SettingsForm(
        settings: row,
        isBlockRunning: engine?.isRunning == true,
        musicAvailability: musicAvailability,
        refreshMusicAvailability: refreshMusicAvailability,
        tokens: tokens,
        cache: cache,
        plan: plan)
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

  /// Whether Apple Music can be used. Defaulted for the same reason the Todoist
  /// collaborators below are optional: this screen must be drawable in a preview
  /// with nothing behind it.
  var musicAvailability: MusicAvailability = .notAsked

  /// Defaulted to doing nothing, for the same preview reason.
  var refreshMusicAvailability: () -> Void = {}

  /// The Todoist collaborators. **Optional so that this screen can be looked at
  /// in a preview with nothing behind it**, which is the arrangement the timer
  /// engine above already uses. In the app all three are always there.
  var tokens: (any TokenStore)?
  var cache: TodoistCacheStore?
  var plan: SessionPlanStore?

  var body: some View {
    Form {
      if isBlockRunning {
        runningBlockNote
      }
      blockLengths
      sprint
      whenABlockEnds
      music
      todoist
    }
    // iOS's own grouped-list background is a grey that fights this app's warm
    // page. Dropping it and painting the page underneath is what makes the sheet
    // look like part of the same app as the timer.
    .scrollContentBackground(.hidden)
    .background(Color(.surfacePrimary).ignoresSafeArea())
  }

  // MARK: Private

  /// Whether there is a credential. Read rather than watched: the Keychain does
  /// not publish changes.
  @State private var hasToken = false

  @State private var isConfirmingSignOut = false

  /// Set when signing out could not be finished, so the row can say so rather
  /// than quietly claiming a disconnection that did not happen.
  @State private var signOutFailed = false

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
      Picker("Pomodoros per sprint", selection: $settings.pomodorosPerSprint) {
        ForEach(Array(SettingsBounds.pomodorosPerSprint), id: \.self) { count in
          Text(Self.spokenPomodoros(count)).tag(count)
        }
      }
      .pickerStyle(.navigationLink)
      .font(Typography.body)
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

  /// One duration row: a label, the current value, and a chevron that opens a
  /// list of every legal value with the current one ticked.
  ///
  /// **The bounds are the control, not a check afterwards.** The list holds the
  /// numbers 1 to 120 and nothing else, so a value outside them cannot be
  /// offered, cannot be chosen, and does not have to be rejected. There is no
  /// validation code on this screen, no error state to design and no alert copy
  /// to write. The upper bound exists so a mis-set value cannot schedule an alarm
  /// days away; the lower one is what makes a whole sprint testable by hand in
  /// eight minutes instead of two hours.
  ///
  /// WHY A LIST AND NOT A PAIR OF PLUS AND MINUS BUTTONS
  /// Both keep the bound inside the control, which is the property that matters
  /// most. The list wins on reach: moving the focus length from 25 to 120, or
  /// down to the 1 that makes the eight-minute hand test possible, is one tap
  /// and one scroll either way. With plus and minus it is ninety-five separate
  /// presses, or a long press with no idea where you have got to — and a
  /// VoiceOver reader gets no long press at all, so for them it is ninety-five
  /// separate swipes on the app's only writable screen.
  private func minutesRow(_ title: String, value: Binding<Int>) -> some View {
    Picker(title, selection: value) {
      ForEach(Array(SettingsBounds.minutes), id: \.self) { minutes in
        // Drawn short, spoken in full: the eye wants the abbreviation and the
        // ear wants the word.
        Text("\(minutes) min")
          .accessibilityLabel(Text(Self.spokenMinutes(minutes)))
          .tag(minutes)
      }
    }
    .pickerStyle(.navigationLink)
    // The label is set from the token table like everything else. The trailing
    // value and the chevron are left to iOS, which draws them in its own
    // secondary grey — this is one of the few places in the app where matching
    // the platform is worth more than restating a role, because a settings row
    // that does not look like a settings row reads as broken.
    .font(Typography.body)
  }

  /// Where Apple Music stands, in the place people look for it.
  ///
  /// **It mirrors the Todoist section below deliberately.** This app talks to two
  /// services and their state should be legible in the same place and the same
  /// shape; a reader should not have to learn where each one hides. That
  /// consistency is the reason for the section, and it is a reason that holds
  /// whether or not a second music service ever arrives.
  ///
  /// **No new setting, and nothing to change here.** `AppSettings` still holds
  /// exactly six values — this is a report, not a control. The switch that turns
  /// music on lives on the timer screen where the choice is actually made,
  /// because D19 puts music decisions before a sprint rather than inside one.
  ///
  /// **Never amber, never a warning triangle**, however badly it has gone. The
  /// same rule the music row already follows: this app not being able to play
  /// music is not an error condition, and the timer is unaffected either way.
  @ViewBuilder
  private var music: some View {
    Section {
      LabeledContent("Status") {
        Text(MusicCopy.settingsStatus(for: musicAvailability))
          .font(Typography.body)
          .foregroundStyle(Color(.textMuted))
      }
      .font(Typography.body)
      .accessibilityElement(children: .combine)
    } header: {
      header("Apple Music")
    } footer: {
      footer(MusicCopy.settingsFooter(for: musicAvailability))
    }
    .listRowBackground(Color(.surfaceRaised))
    // Tied to the section's own lifetime, so closing Settings stops the read.
    .task { refreshMusicAvailability() }
  }

  /// One row in, and — once connected — one way out.
  ///
  /// **The token field is never drawn on this screen.** This file's own doc
  /// comment says there is no text field here and there never may be; the row
  /// pushes to the screen that owns the field instead.
  @ViewBuilder
  private var todoist: some View {
    if let tokens {
      Section {
        NavigationLink {
          TodoistSignInRoute(tokens: tokens, cache: cache) { hasToken = true }
        } label: {
          LabeledContent("Todoist") {
            Text(trailingValue)
              .font(Typography.body)
              .foregroundStyle(Color(.textMuted))
          }
          .font(Typography.body)
        }

        if hasToken {
          Button("Sign out of Todoist", role: .destructive) { isConfirmingSignOut = true }
            .font(Typography.body)
        }
      } header: {
        header("Todoist")
      } footer: {
        footer("ZenTomato reads your projects and tasks. The only change it can make is ticking a task off.")
      }
      .listRowBackground(Color(.surfaceRaised))
      .task { readToken(tokens) }
      .confirmationDialog(
        "Sign out of Todoist?",
        isPresented: $isConfirmingSignOut,
        titleVisibility: .visible) {
        Button("Sign out", role: .destructive) { signOut(tokens) }
        Button("Cancel", role: .cancel) { }
      } message: {
        Text(signOutWarning)
      }
    }
  }

  /// What the row says on its right-hand side.
  private var trailingValue: String {
    if signOutFailed { return "Couldn't sign out" }
    return hasToken ? "Connected" : "Not connected"
  }

  /// Spelled out before the tap, because two of the three things it removes are
  /// not the one somebody has in mind when they choose it.
  private var signOutWarning: String {
    "Your token is removed from this iPhone, along with ZenTomato's copy of your "
      + "projects and tasks and your current plan. Nothing in Todoist changes."
  }

  private func signOut(_ tokens: any TokenStore) {
    signOutFailed = SettingsView.signOutOfTodoist(tokens: tokens, cache: cache, plan: plan) == false
    readToken(tokens)
  }

  private func readToken(_ tokens: any TokenStore) {
    do {
      hasToken = try tokens.read()?.isEmpty == false
    } catch {
      hasToken = false
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
  /// it is the documented edge case where every *completed* focus block is
  /// followed by the long break — so "1 pomodoros" would appear on the very
  /// screen that sets it.
  ///
  /// The word "completed" is load-bearing. A focus block that is skipped earns
  /// nothing, including the long break, so it is followed by a short break even
  /// in a sprint of one. That is the same rule everywhere else in the app: the
  /// long break is earned by finished pomodoros, never by attempts.
  private static func spokenPomodoros(_ count: Int) -> String {
    "\(count) \(count == 1 ? "pomodoro" : "pomodoros")"
  }
}

// MARK: - TodoistSignInRoute

/// The token screen, pushed from the Settings row, with its state owned here.
///
/// **WHY THIS TINY VIEW EXISTS.** `TodoistSignInView` holds its state in a
/// `@Bindable` rather than a `@State`, so whoever pushes it owns the model. A
/// destination written inline in a `NavigationLink` is rebuilt every time its
/// parent's body runs — and this parent reads the running timer, so a break
/// ending flips `isRunning`, the body re-runs, a brand-new empty model replaces
/// the old one, and a half-pasted credential vanishes with no explanation.
/// Holding the model in `@State` here builds it once and keeps it for as long as
/// the screen is on the stack. `PlanBuilderView` already guards the other
/// entrance to the same screen for exactly this reason.
private struct TodoistSignInRoute: View {
  // MARK: Lifecycle

  init(tokens: any TokenStore, cache: TodoistCacheStore?, onConnected: @escaping () -> Void) {
    self.onConnected = onConnected
    _model = State(initialValue: SignInScreenModel(tokens: tokens, cache: cache))
  }

  // MARK: Internal

  var body: some View {
    TodoistSignInView(model: model, onConnected: onConnected)
  }

  // MARK: Private

  private let onConnected: () -> Void

  @State private var model: SignInScreenModel
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
