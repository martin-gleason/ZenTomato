import SwiftUI

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation, and this file is more than half of it —
// because the picker is where the standing no-capture rule is most likely to be
// broken by accident, and the argument against each of the shapes it could be
// broken into is written beside the code that avoids it. The four small views
// below are the empty states of one screen; splitting them into four files
// would separate each state from the screen it belongs to, and would make the
// argument harder to read rather than shorter. The same exemption, for the same
// reason, is already taken by `TimerScreen.swift` and `TimerEngine.swift`.

/// The picker's root: every project on the account, in Todoist's own order.
///
/// **All of them.** `SPEC.md` locks it — *"All projects, sections, and tasks are
/// visible in the picker"* — so nothing is filtered here, at the request, or
/// anywhere between.
///
/// TWO TAP TARGETS PER ROW, AND THEY DO DIFFERENT THINGS
/// The leading square puts the project itself into the plan; the rest of the row
/// goes into it to choose tasks. That split is what lets a project be planned
/// *as a project* — which `SPEC.md`'s vocabulary section allows, and which is
/// the right shape for "spend this pomodoro on the Deep work project" — without
/// losing the way in to its tasks.
///
/// THE SEARCH FIELD IS THE SHARPEST NO-CAPTURE RISK IN THE APP
/// A search that returns nothing is exactly where every other app offers to
/// create the thing you typed. This one offers nothing: no button, no disabled
/// button, no footer, no trailing row, no `ContentUnavailableView` with its own
/// action slot. Three lines of text, the last of which says where tasks come
/// from, and no tap target of any kind. See `PickerScreenModel` for the copy and
/// for why the model can only produce three kinds of row.
struct ProjectPickerView: View {
  // MARK: Internal

  /// Everything mirrored from Todoist, as plain values.
  let picker: PickerScreenModel

  /// How old the mirror is, and whether there is one at all.
  let freshness: PlanBuilderView.Freshness

  /// The plan being built, in the order it was chosen.
  @Binding var selections: [SessionPlanStore.Selection]

  /// What the line along the bottom says — the selection being built, or the
  /// plan that already exists when nothing new has been chosen.
  let planBar: PlanBar.Contents

  let onOpenProject: (PickerScreenModel.Project) -> Void
  let onOpenPlan: () -> Void
  let onRefresh: () async -> Void

  var body: some View {
    content
      .searchable(
        text: $query,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: Text(PickerScreenModel.searchPrompt))
      // Never auto-focused. Arriving at the picker with a keyboard up and a
      // blinking caret is the single most create-shaped thing this screen could
      // do. The field is present, unfocused, and waits.
      .textInputAutocapitalization(.never)
      // Off, so a task title is never quietly rewritten into something that
      // then fails to match.
      .autocorrectionDisabled()
      // Never `.go`, `.send`, `.done` or `.return`. A return key that says "Go"
      // on an empty result is half of a create button.
      .submitLabel(.search)
      .safeAreaInset(edge: .bottom, spacing: Spacing.none) {
        PlanBar(contents: planBar, onOpen: onOpenPlan)
      }
  }

  // MARK: Private

  @State private var query = ""

  @ViewBuilder
  private var content: some View {
    if case .nothingYet = freshness, picker.projects.isEmpty {
      NothingMirroredYetView(onRetry: onRefresh)
    } else {
      list
    }
  }

  private var list: some View {
    List {
      if case .stale(let note) = freshness {
        StaleMirrorBanner(note: note)
      }

      if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Section {
          ForEach(picker.projects) { project in
            projectRow(project)
          }
        } header: {
          header(PickerScreenModel.projectsHeader)
        }
        .listRowBackground(Color(.surfaceRaised))
      } else {
        searchResults
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    .refreshable { await onRefresh() }
  }

  /// Tasks first, then projects. **No trailing row, ever.**
  @ViewBuilder
  private var searchResults: some View {
    let rows = picker.rows(matching: query)
    if rows.isEmpty {
      NoMatchView(query: query)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    } else {
      Section {
        ForEach(rows) { row in
          switch row {
          case .task(let task):
            PickerRowView(
              title: task.title,
              subtitle: task.projectName,
              ordinal: ordinal(for: task.id),
              isSelected: isSelected(task.id),
              onToggle: { toggle(.init(todoistID: task.id, titleSnapshot: task.title, kind: .task)) })

          case .project(let project):
            PickerRowView(
              title: project.name,
              subtitle: PickerScreenModel.taskCountLine(project.openTaskCount),
              ordinal: ordinal(for: project.id),
              isSelected: isSelected(project.id),
              onToggle: {
                toggle(.init(todoistID: project.id, titleSnapshot: project.name, kind: .project))
              },
              onOpen: { onOpenProject(project) })

          case .section:
            // A section is a place, not something to work on, so it is never a
            // search result. The case is written out rather than defaulted so
            // that a fourth kind of row could not slip through unnoticed.
            EmptyView()
          }
        }
      } header: {
        header(PickerScreenModel.resultsHeader)
      }
      .listRowBackground(Color(.surfaceRaised))
    }
  }

  private func projectRow(_ project: PickerScreenModel.Project) -> some View {
    PickerRowView(
      title: project.name,
      subtitle: PickerScreenModel.taskCountLine(project.openTaskCount),
      ordinal: ordinal(for: project.id),
      isSelected: isSelected(project.id),
      onToggle: { toggle(.init(todoistID: project.id, titleSnapshot: project.name, kind: .project)) },
      onOpen: { onOpenProject(project) })
  }

  private func header(_ title: String) -> some View {
    Text(title)
      .font(Typography.kicker)
      .textCase(.uppercase)
      .foregroundStyle(Color(.textMuted))
  }

  private func isSelected(_ id: String) -> Bool {
    selections.contains { $0.todoistID == id }
  }

  /// Where this item sits in the plan, counted from one. `nil` when it is not
  /// in the plan.
  ///
  /// **Selection and order are one fact, shown once, at the moment of the
  /// choice.** Nobody has to go to another screen to learn where the thing they
  /// just tapped landed.
  private func ordinal(for id: String) -> Int? {
    selections.firstIndex { $0.todoistID == id }.map { $0 + 1 }
  }

  private func toggle(_ selection: SessionPlanStore.Selection) {
    if let index = selections.firstIndex(where: { $0.todoistID == selection.todoistID }) {
      selections.remove(at: index)
    } else {
      selections.append(selection)
    }
  }
}

// MARK: - PickerRowView

/// One row of the picker, at every level: a toggle, a title, an ordinal, and —
/// for a project — a way in.
///
/// The unselected glyph is drawn in the **functional** border role, which is the
/// one documented as "the boundary that tells you something is a control". The
/// decorative role would be a defect here.
///
/// **Selection never relies on colour alone.** The filled glyph and the trailing
/// ordinal are both non-colour signals, which matters because the selected
/// ground and the ordinary one are close in lightness.
struct PickerRowView: View {
  // MARK: Internal

  let title: String
  var subtitle: String?
  var ordinal: Int?
  let isSelected: Bool
  let onToggle: () -> Void

  /// Set only on a project row. A task row has nowhere further to go, so the
  /// whole of it toggles instead.
  var onOpen: (() -> Void)?

  /// What VoiceOver says instead of "circle".
  ///
  /// **The subtitle is spoken, and it is load-bearing on a search result.** Task
  /// titles repeat across projects — that is why the second line exists at
  /// all — and the label carrying it is hidden from VoiceOver on a task row, so
  /// without this the project name reaches no reader at all. Somebody searching
  /// "review" would hear "Review the draft, not in your plan" three times with
  /// nothing to tell them apart, and build exactly the plan they cannot trust
  /// that the second line was added to prevent. It also restores the "3 tasks"
  /// count on a project row.
  ///
  /// A pure function of the three things a row draws, so it can be read by a
  /// test with no screen behind it.
  static func spokenToggleLabel(title: String, subtitle: String?, ordinal: Int?) -> String {
    var parts = [title]
    if let subtitle { parts.append(subtitle) }
    parts.append(ordinal.map { "number \($0) in your plan" } ?? "not in your plan")
    return parts.joined(separator: ", ")
  }

  var body: some View {
    HStack(spacing: Spacing.sm) {
      toggleButton

      if let onOpen {
        Button(action: onOpen) { label }
          .buttonStyle(.plain)
          .accessibilityHint(Text("Opens this project."))
        Image(systemName: "chevron.right")
          .font(Typography.label)
          .foregroundStyle(Color(.textMuted))
          .accessibilityHidden(true)
      } else {
        Button(action: onToggle) { label }
          .buttonStyle(.plain)
          .accessibilityHidden(true)
      }
    }
    .listRowBackground(Color(isSelected ? .actionSubtle : .surfaceRaised))
  }

  // MARK: Private

  private var label: some View {
    HStack(spacing: Spacing.sm) {
      VStack(alignment: .leading, spacing: Spacing.xxs) {
        Text(title)
          .font(Typography.body)
          .foregroundStyle(Color(.textPrimary))
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)

        if let subtitle {
          Text(subtitle)
            .font(Typography.label)
            .foregroundStyle(Color(.textMuted))
            .lineLimit(1)
        }
      }

      Spacer(minLength: Spacing.xs)

      if let ordinal {
        Text("\(ordinal)")
          .font(Typography.data)
          .foregroundStyle(Color(.textMuted))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(minHeight: Spacing.controlHeight)
    .contentShape(Rectangle())
  }

  /// The one control that means the same thing at every level of the picker, so
  /// it is learned once.
  ///
  /// **It is a plan control and nothing else.** It must never be drawn as a
  /// Todoist completion checkbox: a round empty circle beside a task in a
  /// Todoist-shaped list is exactly what people tap to tick things off, and this
  /// one writes nothing anywhere.
  private var toggleButton: some View {
    Button(action: onToggle) {
      Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        .font(Typography.label)
        .foregroundStyle(isSelected ? Color(.action) : Color(.borderStrong))
        .frame(width: Spacing.controlHeight, height: Spacing.controlHeight)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(Self.spokenToggleLabel(title: title, subtitle: subtitle, ordinal: ordinal)))
    .accessibilityHint(Text(isSelected ? "Takes it out of your plan." : "Puts it in your plan."))
  }
}

// MARK: - StaleMirrorBanner

/// The quiet line above the list when Todoist could not be reached and there is
/// something mirrored to use.
///
/// **Not amber.** Nothing has failed from where the reader is standing: every
/// project is there, the search works, the plan builds. Amber would be the
/// loudest thing on the screen for a state in which nothing is wrong, and it
/// would spend the screen's one warning.
///
/// There is no "Retry" button: the pull gesture is the retry, and this line
/// names the state rather than demanding an action.
struct StaleMirrorBanner: View {
  let note: String

  var body: some View {
    Text(note)
      .font(Typography.label)
      .foregroundStyle(Color(.textMuted))
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(Spacing.sm)
      .background(Color(.surfaceInset), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .onAppear { AccessibilityNotification.Announcement(note).post() }
  }
}

// MARK: - NoMatchView

/// A search that found nothing.
///
/// **The third line is the whole design.** It is a statement of where tasks come
/// from, placed exactly where every other app puts a create button. It is text,
/// in the quiet ink, with no tap target of any kind.
///
/// `ContentUnavailableView` is deliberately not used: it brings its own
/// oversized glyph, its own type scale, and — in the search variant — a slot
/// designed to hold exactly the action this screen must not offer.
struct NoMatchView: View {
  let query: String

  var body: some View {
    VStack(spacing: Spacing.sm) {
      Text(PickerScreenModel.noMatchHeading)
        .font(Typography.title)
        .foregroundStyle(Color(.textPrimary))

      Text(PickerScreenModel.noMatchDetail(for: query))
        .font(Typography.body)
        .foregroundStyle(Color(.textMuted))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        // Arbitrary typed text may not set the layout of a screen.
        .lineLimit(2)

      Text(PickerScreenModel.noMatchOrigin)
        .font(Typography.body)
        .foregroundStyle(Color(.textMuted))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, Spacing.xl)
  }
}

// MARK: - NothingMirroredYetView

/// Todoist has never been reached, so there is nothing to pick from.
///
/// **This is the state to get right, because it is a first run on a train.**
///
/// The third paragraph is load-bearing: it stops the reader concluding the app
/// is broken and closing it. F3 is an integration; the timer is the product.
struct NothingMirroredYetView: View {
  let onRetry: () async -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.md) {
        Text(PickerScreenModel.nothingMirroredHeading)
          .font(Typography.title)
          .foregroundStyle(Color(.textPrimary))
          .accessibilityAddTraits(.isHeader)

        Text(PickerScreenModel.nothingMirroredExplanation)
          .font(Typography.body)
          .foregroundStyle(Color(.textPrimary))
          .fixedSize(horizontal: false, vertical: true)

        Text(PickerScreenModel.nothingMirroredReassurance)
          .font(Typography.body)
          .foregroundStyle(Color(.textMuted))
          .fixedSize(horizontal: false, vertical: true)

        // A retry button is honest here — unlike the alarm explainer's
        // deliberately absent one, this genuinely does something the app is not
        // already doing.
        Button(PickerScreenModel.tryAgain) { retryRequest = UUID() }
          .buttonStyle(SecondaryButtonStyle(emphasis: .normal))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Spacing.md)
      .padding(.vertical, Spacing.xl)
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    .refreshable { await onRetry() }
    .task(id: retryRequest) {
      guard retryRequest != nil else { return }
      await onRetry()
    }
  }

  @State private var retryRequest: UUID?
}
