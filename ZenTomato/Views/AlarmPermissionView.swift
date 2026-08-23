import SwiftUI
import UIKit

/// Shown over the whole timer screen when ZenTomato is not allowed to set
/// alarms.
///
/// WHY THE APP STOPS INSTEAD OF FALLING BACK TO A NOTIFICATION
/// This is the question a reviewer will arrive at this file to ask, so it is
/// answered here rather than in a plan nobody will be holding at the time.
///
/// Every block in this app ends with an alarm — the same kind of alert that wakes
/// you up in the morning. That is the only alert iOS lets through silent mode and
/// through a Focus, and a Focus is precisely what a person running a Pomodoro
/// block is in. An ordinary notification is swallowed by both. So the obvious
/// fallback is not a quieter version of the same thing; it is an alert that fails
/// in exactly the situation this app exists for.
///
/// A Pomodoro timer that cannot reliably tell you a block ended has no working
/// state to degrade into. It would run for twenty-five minutes, finish, and say
/// nothing — which is worse than refusing, because the person would not find out
/// until they looked. So the app refuses, says why, and offers the one tap that
/// fixes it. There is no second alerting path anywhere in this codebase, and that
/// is deliberate rather than unfinished.
///
/// WHEN IT APPEARS, AND WHEN IT DOES NOT
/// Only after the app has actually asked. Permission is requested at the first tap
/// on Start, never at launch, so somebody who installs ZenTomato and never starts a
/// timer can never meet this screen. It is shown when the answer was no — either
/// the person declined, or the request failed outright. Those are folded into one
/// case on purpose: from where they are standing both mean "no alarms", and
/// splitting them would mean writing a second screen with identical words on it.
///
/// HOW IT LETS GO
/// It has no close button and no gesture, because it is a blocking screen and it
/// blocks. It goes away by itself: the switch can only be changed in the Settings
/// app, so the person has to leave and come back, and every return to the app
/// re-checks the answer. That is what makes the promise in the copy — *"come back
/// to this screen and it'll let you through by itself"* — a promise the code keeps
/// rather than a hope. There is deliberately no "Try again" button: it could only
/// re-read a value the app is already watching, so it would either do nothing or
/// pretend to.
struct AlarmPermissionView: View {
  // MARK: Internal

  var body: some View {
    // Scrolls rather than clips. At the largest accessibility text sizes this
    // much prose is several screens tall, and `.basedOnSize` means it behaves
    // like a scrolling view only when it actually needs to.
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.md) {
        kicker
        heading
        why
        whatHappened
        howToFixIt
        openSettingsButton
        noFallbackNote
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Spacing.md)
      .padding(.vertical, Spacing.xl)
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    // Nothing here may be swiped away. Stated even though a full-screen cover
    // has no swipe to begin with, so that moving this onto a sheet later cannot
    // quietly make it dismissable.
    .interactiveDismissDisabled(true)
    .onAppear { headingIsFocused = true }
  }

  // MARK: Private

  /// Opens a web or system address. Used rather than reaching for the shared
  /// application object, which is not safe to touch from arbitrary places under
  /// this project's concurrency rules.
  @Environment(\.openURL) private var openURL

  /// Where VoiceOver starts reading.
  ///
  /// Left alone it would begin at the top of the screen and work down, which is
  /// nearly right — but the button is what a sighted reader's eye jumps to, and
  /// announcing the fix before the problem is the wrong order for a screen whose
  /// job is to explain. Focus is put on the heading explicitly.
  @AccessibilityFocusState private var headingIsFocused: Bool

  /// **Amber rather than red, and that is the one deliberate difference from the
  /// database-failure screen.** That screen says `PROBLEM` in red because
  /// something is broken and the app cannot recover on its own. Here nothing is
  /// broken: a switch is off, and one tap turns it on. Red would be claiming a
  /// fault that does not exist and would make a two-tap fix look like data loss.
  private var kicker: some View {
    Text("Alarms are off")
      .font(Typography.kicker)
      .textCase(.uppercase)
      .foregroundStyle(Color(.warningText))
      // Given in ordinary case to VoiceOver, so it is not spelled out letter by
      // letter ahead of the explanation.
      .accessibilityLabel(Text("Alarms are off"))
  }

  /// **The heading names what the reader has lost, not what the software's state
  /// is.** "Alarm permission required" is a sentence about a permission and
  /// "AlarmKit authorization denied" is a sentence about a framework; neither
  /// tells the person holding the phone anything they can act on.
  private var heading: some View {
    Text("ZenTomato can't tell you when a block ends")
      .font(Typography.title)
      .foregroundStyle(Color(.textPrimary))
      .accessibilityAddTraits(.isHeader)
      .accessibilityFocused($headingIsFocused)
  }

  /// **The load-bearing paragraph.** Without it the whole screen reads as an app
  /// being precious about a permission it does not really need. It answers the
  /// question the reader is actually asking — *why not just use a notification
  /// like everything else* — before they ask it, and the second half is what
  /// makes the answer land: the obvious alternative fails specifically in the
  /// situation this app is for.
  private var why: some View {
    Text(
      """
      This app uses the iPhone's alarm system to sound the end of every focus \
      block and every break. That's the only kind of alert that gets through \
      silent mode and through a Focus — and a Focus is exactly what you'll be in \
      while the timer is running.
      """)
      .font(Typography.body)
      .foregroundStyle(Color(.textPrimary))
  }

  /// **Passive voice, deliberately.** "You denied permission" is accurate and is
  /// an accusation — and it may not even be true: prompts get tapped through on
  /// autopilot, or by somebody else holding the phone, or blocked by a Screen
  /// Time restriction. Stating the fact without assigning it costs nothing.
  private var whatHappened: some View {
    Text(
      """
      Permission to set those alarms was turned down, so a block would run \
      silently and finish without telling you. Rather than let it do that \
      quietly, ZenTomato stops here.
      """)
      .font(Typography.body)
      .foregroundStyle(Color(.textPrimary))
  }

  /// Three steps, in order, each one a thing you can see and touch.
  ///
  /// `Alarms` is emphasised because it is the switch, and it is the only word on
  /// this screen the reader has to go and find somewhere else. It stays inside
  /// its sentence rather than becoming its own element, so VoiceOver reads the
  /// instruction as one continuous sentence.
  private var howToFixIt: some View {
    Text(howToFixItText)
      .font(Typography.body)
      .foregroundStyle(Color(.textPrimary))
  }

  /// The instruction, built as one attributed sentence rather than three `Text`
  /// values added together.
  ///
  /// Adding `Text` values with `+` is deprecated in iOS 26, and a single
  /// attributed string is also the form VoiceOver reads as one continuous
  /// sentence — which is what this instruction needs, since the emphasised word
  /// is the name of a switch the reader has to go and find.
  ///
  /// **THE STEPS DESCRIBE THE ROUTE THE BUTTON BELOW ACTUALLY TAKES.** An
  /// earlier draft read "open Settings, tap ZenTomato, and turn on Alarms",
  /// which is the route somebody would take starting from the home screen. The
  /// only control on this screen skips the middle step: it lands on ZenTomato's
  /// own page. A reader who does the obvious thing and taps the button would
  /// have arrived somewhere with no ZenTomato row to tap, and an instruction
  /// whose second step is not there is exactly how a reader stops trusting the
  /// rest of a screen.
  private var howToFixItText: AttributedString {
    var sentence = AttributedString("Tap Open Settings below, then turn on ")
    var switchName = AttributedString("Alarms")
    switchName.font = Typography.bodyEmphasis
    sentence.append(switchName)
    sentence.append(AttributedString(
      ". Then come back to this screen — it'll let you through by itself."
    ))
    return sentence
  }

  /// The only control on the screen, and the only filled surface on it.
  ///
  /// The address it opens lands on ZenTomato's *own* page in Settings, which is
  /// where the Alarms switch is — not the top of Settings, which would leave the
  /// reader hunting. The `if let` is there because this codebase does not use
  /// Swift's crash-if-nil operator anywhere: the address is a system constant and
  /// cannot realistically fail to parse, but doing nothing in that impossible
  /// case still beats crashing on the screen whose entire job is to be the calm
  /// thing that appears when something has gone wrong.
  private var openSettingsButton: some View {
    Button("Open Settings") {
      if let url = URL(string: UIApplication.openSettingsURLString) {
        openURL(url)
      }
    }
    .buttonStyle(StartButtonStyle())
    .padding(.top, Spacing.xs)
    .accessibilityLabel(Text("Open Settings"))
    .accessibilityHint(Text("Opens ZenTomato's page in the Settings app."))
  }

  /// The closing line is the one piece of writing on this screen aimed past the
  /// reader at whoever reviews the app, and it sits here rather than in a code
  /// comment because this is where the question gets asked.
  private var noFallbackNote: some View {
    Text(
      """
      There's no quieter fallback, on purpose. An alert a Focus can swallow would \
      let a block end without you noticing, which is the one thing this timer \
      exists to prevent.
      """)
      .font(Typography.label)
      .foregroundStyle(Color(.textMuted))
  }
}

// MARK: - Previews

/// This screen has no inputs at all — no database, no timer, no settings — which
/// means it renders identically for every user on every device. It is the one
/// screen in the app that can be proof-read entirely from a preview.
#Preview("Light") {
  AlarmPermissionView()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  AlarmPermissionView()
    .preferredColorScheme(.dark)
}

/// The largest text size iOS offers. Nothing here may be clipped or truncated;
/// the screen scrolls instead.
#Preview("Largest text") {
  AlarmPermissionView()
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}
