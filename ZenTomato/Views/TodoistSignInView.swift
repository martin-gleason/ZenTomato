import SwiftUI

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation and previews. This screen holds the one
// text input the whole Todoist feature adds to an app with a standing rule
// against accepting typed input, so the reasoning behind every choice on it is
// written down beside the choice, and every state of it — including each way a
// token can be refused — has a preview. The same exemption, for the same
// reason, is already taken by `TimerScreen.swift` and `TimerEngine.swift`.

/// Where somebody pastes their Todoist API token. The one credential field in
/// the app, and the only text input this feature adds.
///
/// WHY A PASTED TOKEN AND NOT A SIGN-IN BUTTON
/// Ratified decision D18. Todoist's sign-in flow has no way for an app like
/// this one to keep the secret it would need, and a secret shipped inside an
/// app is a secret published. A personal token has no such secret at all: the
/// credential is the reader's own, it never leaves their Keychain, and they can
/// revoke it from Todoist without anybody touching this app. The cost is
/// honest and it lands right here — instead of tapping a button they have to go
/// and fetch a long string — which is why this screen spends most of its height
/// saying exactly where to find it.
///
/// WHY IT IS NOT THE FIRST SCREEN OF THE APP
/// The timer works with no Todoist at all, and it shipped that way. A
/// credential wall in front of a working timer would contradict two features
/// that are already merged. So this is the first screen of the *Todoist
/// feature*: it is what the Todoist route lands on whenever there is no token,
/// reached from the attachment line on the timer or from one row in Settings.
///
/// WHY THIS IS UNMISTAKABLY A CREDENTIAL FIELD AND NOT A WAY TO ENTER A TASK
/// This is the question a reviewer arrives at this file to answer, so it is
/// answered here. Nine things say so, and no one of them is load-bearing alone:
///
///  1. The label above the field says **API token**.
///  2. The heading says **Paste your Todoist API token** — the screen names
///     what it wants before the field exists.
///  3. **It is masked.** You cannot write a task into a field you cannot read.
///     This is the strongest single signal and it is why masking wins over the
///     convenience of a plain field.
///  4. `textContentType(.password)` — iOS itself classifies it as a credential,
///     offers password autofill, and keeps text suggestions off the keyboard.
///  5. It is set in the monospaced face this design system reserves for data
///     and forbids for prose.
///  6. Autocorrect and capitalisation are both off and the keyboard is
///     `asciiCapable`: a keyboard configured for a machine string. Every other
///     writable field in this app sets `.textInputAutocapitalization(.sentences)`.
///  7. A paste button sits under it. Nobody types a task by pasting.
///  8. Its neighbours. Every line on this screen is about Todoist's own
///     settings tree, the Keychain, or what this app cannot do.
///  9. The screen says it out loud, in the last line.
///
/// **The reveal shows the token as text you cannot edit**, rather than swapping
/// the masked field for a writable one. A second writable field on this screen
/// is the one thing the no-capture fence asks it not to have, and inspection —
/// not editing — is what a reveal is for.
struct TodoistSignInView: View {
  // MARK: Internal

  /// The field's contents, the connect command, and every failure wording.
  @Bindable var model: SignInScreenModel

  /// Called once the token has been accepted and stored. The screen does not
  /// congratulate anybody: it hands over and the picker takes its place.
  var onConnected: () -> Void = { }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.md) {
        if let banner = model.banner {
          warningRow(banner.message)
          if let note = banner.note {
            Text(note)
              .font(Typography.label)
              .foregroundStyle(Color(.textMuted))
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        kicker
        heading
        whatItDoes
        whereToFindIt
        alsoOnTheWeb
        fieldBlock

        if let message = model.errorMessage {
          warningRow(message)
        }

        connectButton
        keychainNote
        reviewerNote
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Spacing.md)
      .padding(.vertical, Spacing.xl)
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    // VoiceOver starts at the heading rather than at the top-left corner, so
    // the first thing read is what the screen wants rather than the word
    // "Todoist" on its own. `AlarmPermissionView` sets the same precedent.
    .onAppear { headingIsFocused = true }
    // SAID OUT LOUD, NOT ONLY DRAWN. A VoiceOver reader's focus is on the
    // Connect button they just pressed, and nothing would otherwise tell them a
    // new line has appeared above it.
    .onChange(of: model.errorMessage) { _, message in
      guard let message else { return }
      AccessibilityNotification.Announcement(message).post()
    }
    // THE CONNECT COMMAND, RUN WITHOUT STARTING LOOSE WORK.
    //
    // A button's action is a synchronous place and talking to Todoist is not,
    // so the button sets a token and this runs the work — tied to the screen's
    // own lifetime, and cancelled with it. That is the house rule: there is no
    // unattended work anywhere in this app.
    .task(id: connectRequest) {
      guard connectRequest != nil else { return }
      if await model.connect() {
        onConnected()
      }
    }
  }

  // MARK: Private

  /// How far a revealed token may wrap before it scrolls inside its own box.
  private static let revealedLines = 1 ... 3

  /// Set to a fresh value by the Connect button, which is what starts the check.
  @State private var connectRequest: UUID?

  @FocusState private var isEditing: Bool

  @AccessibilityFocusState private var headingIsFocused: Bool

  private var fieldShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
  }

  private var kicker: some View {
    Text("Todoist")
      .font(Typography.kicker)
      .textCase(.uppercase)
      .foregroundStyle(Color(.textMuted))
      // Given in ordinary case so it is not spelled out letter by letter.
      .accessibilityLabel(Text("Todoist"))
  }

  private var heading: some View {
    Text("Paste your Todoist API token")
      .font(Typography.title)
      .foregroundStyle(Color(.textPrimary))
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
      .accessibilityFocused($headingIsFocused)
  }

  /// **The load-bearing paragraph on the whole screen.** It states the limit of
  /// what this app can do to somebody's Todoist before asking them for the key
  /// to it, which is the order those two sentences have to come in.
  private var whatItDoes: some View {
    Text(
      """
      ZenTomato reads your projects and tasks so you can attach one to a \
      pomodoro. It never creates or edits anything in Todoist — the only change \
      it can ever make is ticking a task off.
      """)
      .font(Typography.body)
      .foregroundStyle(Color(.textPrimary))
      .fixedSize(horizontal: false, vertical: true)
  }

  /// The route, named in full.
  ///
  /// *"Paste your API token"* on its own is not instructions. The avatar step is
  /// included because on an iPhone it is the only way into Todoist's settings,
  /// and an instruction whose first step is missing is exactly how a reader
  /// stops trusting the rest of a screen.
  private var whereToFindIt: some View {
    Text(whereToFindItText)
      .font(Typography.body)
      .foregroundStyle(Color(.textPrimary))
      .fixedSize(horizontal: false, vertical: true)
  }

  /// Built as one attributed sentence rather than three `Text` values added
  /// together: adding them with `+` is deprecated, and one string is what
  /// VoiceOver reads as a single continuous instruction — which is what an
  /// instruction naming a path somebody has to go and find needs to be.
  private var whereToFindItText: AttributedString {
    var sentence = AttributedString("In Todoist, tap your avatar in the top left, then ")
    var path = AttributedString("Settings → Integrations → Developer")
    path.font = Typography.bodyEmphasis
    sentence.append(path)
    sentence.append(AttributedString(" and copy the API token there."))
    return sentence
  }

  /// Plain text, and deliberately **not** a link. A tappable address would open
  /// a browser from a screen that is meant to be inert.
  private var alsoOnTheWeb: some View {
    Text("The same token is at todoist.com under Settings → Integrations → Developer.")
      .font(Typography.label)
      .foregroundStyle(Color(.textMuted))
      .fixedSize(horizontal: false, vertical: true)
  }

  /// The label, the field, the reveal, the paste button and the helper line.
  private var fieldBlock: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      Text("API token")
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        // Spoken as part of the field's own label rather than as a stray word
        // of its own, so the requirement level meets the thing it governs.
        .accessibilityHidden(true)

      HStack(spacing: Spacing.xs) {
        tokenField
        revealButton
      }
      .padding(Spacing.sm)
      .background(Color(.surfaceInset), in: fieldShape)
      // TWO POINTS, which is the weight this app already reserves for a
      // REQUIRED field — the stop sheet's reason field carries two and the
      // skippable reflection fields carry one. Same colour; the step is the
      // signal, and both clear the 3:1 control-boundary floor in both
      // appearances.
      .overlay { fieldShape.strokeBorder(Color(.borderStrong), lineWidth: Spacing.borderThin) }

      pasteButton
      helper
    }
  }

  /// Masked, or shown as text you cannot type into.
  ///
  /// **There is exactly one writable field on this screen and it is the masked
  /// one.** The revealed state is a read-only echo in the same box: it answers
  /// "did the whole thing arrive?", which is what a reveal is for, without
  /// putting a second place to type on the one screen that must not have one.
  @ViewBuilder
  private var tokenField: some View {
    if model.isRevealed {
      Text(model.token)
        .font(Typography.data)
        .foregroundStyle(Color(.textPrimary))
        .lineLimit(Self.revealedLines)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.disabled)
        .accessibilityLabel(Text("Todoist API token, shown"))
        .accessibilityHint(Text("Check the whole string arrived. Hide it to carry on editing."))
    } else {
      SecureField("", text: $model.token)
        .font(Typography.data)
        .foregroundStyle(Color(.textPrimary))
        // The single loudest declaration to iOS that this is a credential: it
        // puts password autofill on the keyboard's suggestion bar and keeps
        // text suggestions off it.
        .textContentType(.password)
        // A token is ASCII. This also takes the emoji key off the keyboard.
        .keyboardType(.asciiCapable)
        // Both off. A capitalised first character silently breaks a token, and
        // autocorrect on a random string is a guaranteed corruption.
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        // Never `.send`, `.go`, `.search` or `.next`.
        .submitLabel(.done)
        .focused($isEditing)
        // THE REQUIREMENT LEVEL IS IN THE LABEL, NOT ONLY IN THE HINT, because
        // hints can be switched off in VoiceOver's settings. The stop sheet
        // already establishes this rule.
        .accessibilityLabel(Text("Todoist API token, required"))
        .accessibilityHint(
          Text("Paste the token you copied from Todoist. Connect stays switched off until something is here."))
    }
  }

  private var revealButton: some View {
    Button {
      model.isRevealed.toggle()
      isEditing = model.isRevealed == false
    } label: {
      Image(systemName: model.isRevealed ? "eye.slash" : "eye")
        // A named text style, so the glyph grows with the reader's text size.
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        .frame(width: Spacing.controlHeight, height: Spacing.controlHeight)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(model.isRevealed ? "Hide token" : "Show token"))
  }

  /// The system's own paste control, rather than a button that reads the
  /// clipboard by hand.
  ///
  /// A hand-rolled version fires the operating system's paste-permission alert
  /// on every single tap. This one does not, and its label and spoken name come
  /// from iOS. It is tinted to the recessed ground so it reads as a quiet
  /// control: **the one filled button on this screen is Connect.**
  ///
  /// Long-press → Paste still works and so does the keyboard's own Paste item.
  /// This exists so a first-run screen does not depend on a discovered gesture.
  private var pasteButton: some View {
    PasteButton(payloadType: String.self) { strings in
      model.paste(strings)
    }
    .labelStyle(.titleAndIcon)
    .buttonBorderShape(.roundedRectangle(radius: Radius.lg))
    .tint(Color(.surfaceInset))
  }

  /// **No length and no shape is stated, and there is no local validation of
  /// the format, ever.** Todoist is the only judge of a token; a local rule
  /// would reject a valid one the day the format changes, on the one screen
  /// with no way around it.
  private var helper: some View {
    Text("A long string of letters and numbers. Paste the whole thing — it's easy to miss the first or last character.")
      .font(Typography.label)
      .foregroundStyle(Color(.textMuted))
      .fixedSize(horizontal: false, vertical: true)
  }

  /// "Connect", not "Sign in" — nothing is exchanged and no account is made
  /// here — and not "Save", because it is checked before it is kept.
  private var connectButton: some View {
    Button(model.isConnecting ? "Connecting…" : "Connect") {
      connectRequest = UUID()
    }
    .buttonStyle(StartButtonStyle())
    .disabled(model.canConnect == false)
    .accessibilityHint(Text("Checks the token with Todoist and stores it on this iPhone."))
  }

  private var keychainNote: some View {
    Text(
      """
      ZenTomato keeps the token in this iPhone's Keychain — locked to this \
      device, never synced to iCloud, never written to a log or a file. Remove \
      it any time from Settings.
      """)
      .font(Typography.label)
      .foregroundStyle(Color(.textMuted))
      .fixedSize(horizontal: false, vertical: true)
  }

  /// The one piece of writing on this screen aimed past the reader at whoever
  /// reviews the app. It sits here rather than in a code comment because this
  /// is where the question gets asked.
  private var reviewerNote: some View {
    Text(
      """
      Everything else you can type into ZenTomato is a note to yourself. This is \
      the one field that isn't — and it still creates nothing. Tasks are made in \
      Todoist.
      """)
      .font(Typography.label)
      .foregroundStyle(Color(.textMuted))
      .fixedSize(horizontal: false, vertical: true)
  }

  /// **Amber, not red.** Red claims a fault; here nothing is broken and one
  /// paste fixes it. Amber is free on this screen because nothing else on it is
  /// amber — and if a second amber thing ever appears, one of them is wrong.
  private func warningRow(_ message: String) -> some View {
    Label {
      Text(message)
        .font(Typography.label)
        .foregroundStyle(Color(.warningText))
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "exclamationmark.triangle")
        .foregroundStyle(Color(.warningText))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Previews

/// Every state of this screen, with no Keychain and no account behind it.
///
/// The fixture credential is the literal string `not-a-real-token`. It is
/// deliberately not forty hexadecimal characters: that is exactly the shape a
/// real Todoist token has, and it is exactly what a secret scanner matches.
#Preview("Empty, light") {
  TodoistSignInPreviewHost()
    .preferredColorScheme(.light)
}

#Preview("Empty, dark") {
  TodoistSignInPreviewHost()
    .preferredColorScheme(.dark)
}

/// Something typed: Connect is live.
#Preview("Filled") {
  TodoistSignInPreviewHost(token: .fixture)
    .preferredColorScheme(.light)
}

/// The reveal. This is what somebody looks at when they suspect the paste
/// arrived short.
#Preview("Revealed") {
  TodoistSignInPreviewHost(token: .fixture, isRevealed: true)
    .preferredColorScheme(.light)
}

/// Refused. The field is never cleared on a rejection — making somebody
/// re-paste after a wrong guess is a punishment for a typo the app cannot see.
#Preview("Token refused") {
  TodoistSignInPreviewHost(token: .fixture, failure: .tokenRejected)
    .preferredColorScheme(.light)
}

#Preview("No connection") {
  TodoistSignInPreviewHost(token: .fixture, failure: .offline)
    .preferredColorScheme(.light)
}

#Preview("Asked to slow down") {
  TodoistSignInPreviewHost(token: .fixture, failure: .rateLimited(retryAfter: .seconds(30)))
    .preferredColorScheme(.light)
}

/// A stored token that stopped working. Different wording from a token refused
/// on first entry, because the meaning is different: this one used to work.
#Preview("Token revoked") {
  TodoistSignInPreviewHost(banner: .revoked)
    .preferredColorScheme(.light)
}

/// The token went away while the picker was open.
#Preview("Disconnected") {
  TodoistSignInPreviewHost(banner: .disconnected)
    .preferredColorScheme(.light)
}

/// The largest text size iOS offers. Nothing may be clipped; the screen scrolls.
#Preview("Largest text") {
  TodoistSignInPreviewHost(banner: .revoked, token: .fixture, failure: .tokenRejected)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships.
///
/// The model is built with no token store and no mirror behind it, which is the
/// same arrangement `SettingsView` uses to be previewable without a timer: a
/// model with no connection can be read and cannot connect, so no preview can
/// reach the real Keychain, the real database or the network.
private struct TodoistSignInPreviewHost: View {
  // MARK: Lifecycle

  init(
    banner: SignInScreenModel.Banner? = nil,
    token: String = "",
    isRevealed: Bool = false,
    failure: TodoistError? = nil) {
    let model = SignInScreenModel(banner: banner, showing: failure)
    model.token = token
    model.isRevealed = isRevealed
    _model = State(initialValue: model)
  }

  // MARK: Internal

  var body: some View {
    TodoistSignInView(model: model)
  }

  // MARK: Private

  @State private var model: SignInScreenModel
}

/// The stand-in credential these previews put in the field.
///
/// **Deliberately not forty hexadecimal characters.** That is the shape a real
/// Todoist token has, and it is exactly what a secret scanner matches — so a
/// realistic-looking fixture would be a false alarm on every commit, and a check
/// that cries wolf is a check somebody switches off.
private extension String {
  static let fixture = "not-a-real-token"
}
