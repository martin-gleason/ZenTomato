import SwiftUI

/// One sentence field per tap, with the kind and the time above it.
///
/// WHY THIS IS A FILE OF ITS OWN AND NOT WRITTEN TWICE
/// Two sheets ask for these sentences: the one at the end of a focus block, and
/// the merged stop sheet, where the same fields sit under a *required* reason.
/// Ratified decision D14 is that stopping mid-block shows one sheet rather than
/// two back to back — and this file is what makes that one *composition* rather
/// than two copies of a layout that would drift apart the first time either was
/// touched. The sheets differ in what surrounds these rows; the rows themselves
/// are the same rows, by construction.
///
/// NOTHING HERE CAN LOSE A RECORD
/// Every row drawn below already exists in the database: it was written the
/// instant the button was tapped, before anything buzzed. This view only ever
/// collects an **optional annotation** to add to a row that is already safe. A
/// field left untouched is a completely normal outcome — the counts alone are
/// the data the spec asks for — and nothing in the copy, the layout or the
/// spoken description may imply otherwise.
///
/// WHY EVERY FIELD RESTS ONE LINE TALL
/// The required field on the stop sheet rests three lines tall. These rest one
/// and grow to four as they are typed into. That difference is not decoration:
/// a field that rests three lines tall looks like a place a paragraph is
/// expected, and one line that grows looks like a place a sentence *could* go.
/// The resting height is the politest available statement of a requirement
/// level, it is readable across a room before a single word is parsed, and it is
/// what makes six of these survivable at the largest accessibility text size —
/// six one-line fields are about 500 points of scrolling where six four-line
/// fields would be roughly 1,500.
struct ReflectionFieldList: View {
  // MARK: Internal

  /// The taps of one block, oldest first.
  ///
  /// A `DistractionPrompt` is a plain immutable value — an id, a kind and an
  /// instant. The stored row it came from never crosses into a screen, which is
  /// what makes it impossible for anything drawn here to modify what the
  /// database believes.
  let prompts: [DistractionPrompt]

  /// What has been typed, keyed by the id of the tap it belongs to.
  ///
  /// Held by whichever screen is presenting the sheet, not by the sheet, so a
  /// dismissal cannot strand a half-written sentence somewhere unreachable —
  /// and so that a sentence typed into the stop sheet is still in the field if
  /// the person changes their mind, keeps going, and meets the same tap again
  /// at the end of the block.
  ///
  /// Keyed by id rather than by position. A list can be re-fetched in a
  /// different order; an id cannot become a different tap.
  @Binding var notes: [UUID: String]

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.lg) {
      ForEach(prompts) { prompt in
        row(prompt)
      }
    }
  }

  // MARK: Private

  /// How many lines a sentence field may grow to before it starts scrolling
  /// inside itself. Four is about as much as fits beside five other rows at the
  /// largest text size; it is a ceiling on the layout, not on what may be said.
  private static let fieldLines = 1 ... 4

  private var field: RoundedRectangle {
    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
  }

  private func row(_ prompt: DistractionPrompt) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      // ONE `Text`, NOT A KIND AND A TIME SIDE BY SIDE.
      //
      // "Internal · 14:32" as a single string wraps naturally onto two lines at
      // the accessibility sizes. A kind and a time laid out as two elements is a
      // layout that has to be re-solved at every text size and will eventually
      // truncate the timestamp — and a truncated timestamp is a wrong record on
      // screen, in the one dataset this app exists to produce.
      Text(rowLabel(prompt))
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        // DRAWN, BUT NOT SPOKEN — because the field below already says it.
        //
        // Its accessibility label is "Note for the internal distraction at
        // 14:32", which repeats this caption word for word. Left visible to
        // VoiceOver, six taps would be twelve elements to swipe through instead
        // of six, with the middle dot read aloud as punctuation on the
        // redundant half — and on the stop sheet a reader has to traverse this
        // whole list to reach the pinned buttons. The stop sheet hides its
        // "Required" kicker from VoiceOver for exactly this reason.
        .accessibilityHidden(true)

      // THE PLACEHOLDER IS EMPTY, AND THAT IS NOT A STYLISTIC CHOICE.
      //
      // Placeholder text renders in `textSubtle`, which on the `surfaceInset`
      // ground below measures 4.13:1 in light — under the 4.5:1 floor, and
      // legal only inside a *disabled* control. These are enabled. So a
      // well-meant "Optional…" would be a contrast defect as well as exactly
      // the nagging the copy on both sheets is carefully avoiding.
      TextField("", text: binding(for: prompt.id), axis: .vertical)
        .font(Typography.body)
        .foregroundStyle(Color(.textPrimary))
        .textInputAutocapitalization(.sentences)
        .lineLimit(Self.fieldLines)
        .padding(Spacing.sm)
        .background(Color(.surfaceInset), in: field)
        // A one-point outline. The required field on the stop sheet carries two
        // points of the same colour, and the step between them is one of the
        // five signals that tell the two requirement levels apart. Both clear
        // the 3:1 floor for a control boundary in both appearances. Dropping
        // these to `border` would not: that role is documented as decorative
        // and using it on a control boundary is a defect.
        .overlay { field.strokeBorder(Color(.borderStrong), lineWidth: Spacing.borderHairline) }
        .accessibilityLabel(Text(spokenFieldLabel(prompt)))
        // A DELIBERATE ASYMMETRY BETWEEN THE DRAWN SHEET AND THE SPOKEN ONE.
        //
        // Visually these rows carry no "Optional" marker at all, because
        // absence is the signal and a tag on every row would be nagging by
        // inversion. In audio, absence is not a signal: a VoiceOver reader
        // hears nothing where a sighted reader sees a shorter field and a
        // missing word. So the requirement level is spoken even though it is
        // not drawn — and it is spoken in the *label* rather than only in the
        // hint below, because hints can be switched off in VoiceOver's settings
        // and a requirement level that disappears with them is not a signal
        // either.
        .accessibilityHint(Text("Leave it blank if you'd rather."))
    }
  }

  /// A binding into one entry of the drafts dictionary.
  ///
  /// A missing entry reads as an empty field rather than as an error, and
  /// typing into a field creates its entry. Nothing is written to the database
  /// here: these drafts become notes only when a sheet is finished with, and a
  /// draft that is blank or nothing but whitespace becomes `nil` rather than an
  /// empty sentence — which is what keeps "skipped" and "deliberately said
  /// nothing" two different facts in the log.
  private func binding(for id: UUID) -> Binding<String> {
    Binding(
      get: { notes[id] ?? "" },
      set: { notes[id] = $0 })
  }

  /// "Internal · 14:32".
  ///
  /// The time is formatted by the reader's own clock setting, so a 24-hour
  /// device shows "14:32" and a 12-hour one shows "2:32 PM". It is never a
  /// hard-coded "HH:mm": a timestamp printed in a format the reader does not
  /// use is a small piece of the log they have to translate every time.
  private func rowLabel(_ prompt: DistractionPrompt) -> String {
    "\(prompt.kind.captureLabel) · \(Self.time(prompt.timestamp))"
  }

  /// "Note for the internal distraction at 14:32".
  private func spokenFieldLabel(_ prompt: DistractionPrompt) -> String {
    "Note for the \(prompt.kind.spokenLabel) distraction at \(Self.time(prompt.timestamp)). Optional."
  }

  private static func time(_ instant: Date) -> String {
    instant.formatted(date: .omitted, time: .shortened)
  }
}

// MARK: - DistractionKind naming

/// What a kind is called on screen and out loud.
///
/// **The definitions live in `DistractionTally.swift`, which this app does not
/// touch** — that file is the owner's, and its doc comments are where "internal"
/// and "external" are explained. This extension only decides how the two kinds
/// are *spelled* in the interface, and it exists so they are spelled in exactly
/// one place: the capture buttons, the row labels on both sheets and the
/// accessibility descriptions all read from here, so none of them can drift into
/// its own vocabulary.
///
/// The same two words are what `DistractionTally.summary(of:)` prints in its
/// "2 internal · 1 external" line, so every surface in the feature speaks one
/// language and nothing has to translate.
extension DistractionKind {
  /// The word on a button and at the head of a row: "Internal", "External".
  var captureLabel: String {
    switch self {
    case .internalInterruption: "Internal"
    case .externalInterruption: "External"
    }
  }

  /// The same word inside a spoken sentence, where a capital letter would be
  /// wrong: "Note for the internal distraction at 14:32".
  var spokenLabel: String {
    switch self {
    case .internalInterruption: "internal"
    case .externalInterruption: "external"
    }
  }
}

// MARK: - Previews

#Preview("One tap") {
  ReflectionFieldListPreviewHost(prompts: .previewOneTap)
    .preferredColorScheme(.light)
}

#Preview("Three taps") {
  ReflectionFieldListPreviewHost(prompts: .previewThreeTaps)
    .preferredColorScheme(.light)
}

#Preview("Three taps, dark") {
  ReflectionFieldListPreviewHost(prompts: .previewThreeTaps)
    .preferredColorScheme(.dark)
}

/// The hard case: six rows at the largest text size, which is what the
/// one-line resting height exists for.
#Preview("Six taps, largest text") {
  ReflectionFieldListPreviewHost(prompts: .previewSixTaps)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships.
private struct ReflectionFieldListPreviewHost: View {
  init(prompts: [DistractionPrompt]) {
    self.prompts = prompts
    _notes = State(initialValue: [:])
  }

  let prompts: [DistractionPrompt]

  var body: some View {
    ScrollView {
      ReflectionFieldList(prompts: prompts, notes: $notes)
        .padding(Spacing.lg)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.surfacePrimary))
  }

  @State private var notes: [UUID: String]
}

/// Fixtures for this file's previews. Never part of what ships.
///
/// Private, and therefore repeated in the two sheet files that also need a
/// handful of taps to draw. That is the convention already set by every other
/// screen in this app — `TimerScreen`, `StopReasonSheet` and `TimerControls`
/// each keep their own preview data private to the file — and it is the right
/// trade here: a shared internal fixture would be preview scaffolding compiled
/// into the shipping app, visible from anywhere, and one edit away from
/// becoming real data somebody draws by accident.
private extension [DistractionPrompt] {
  static var previewOneTap: [DistractionPrompt] {
    [prompt(.internalInterruption, minute: 32)]
  }

  static var previewThreeTaps: [DistractionPrompt] {
    [
      prompt(.internalInterruption, minute: 32),
      prompt(.externalInterruption, minute: 41),
      prompt(.internalInterruption, minute: 58)
    ]
  }

  static var previewSixTaps: [DistractionPrompt] {
    [
      prompt(.internalInterruption, minute: 32),
      prompt(.externalInterruption, minute: 35),
      prompt(.internalInterruption, minute: 41),
      prompt(.internalInterruption, minute: 47),
      prompt(.externalInterruption, minute: 52),
      prompt(.externalInterruption, minute: 58)
    ]
  }

  /// A tap at a fixed instant, so a preview looks the same every time it is
  /// opened rather than drifting with the clock.
  static func prompt(_ kind: DistractionKind, minute: Int) -> DistractionPrompt {
    let components = DateComponents(year: 2026, month: 8, day: 23, hour: 14, minute: minute)
    let instant = Calendar(identifier: .gregorian).date(from: components)
    return DistractionPrompt(
      id: UUID(),
      kind: kind,
      timestamp: instant ?? Date(timeIntervalSince1970: 0))
  }
}
