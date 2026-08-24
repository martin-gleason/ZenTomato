import SwiftUI

/// How many pomodoros you did — today first, then by day, project and task.
///
/// **The screen opens with today's count.** Minutes into the first real session
/// the owner asked *"how do I see how many pomodoros I did in a day?"* — not a
/// week, not per project. That is what this screen owes first, so it is one large
/// number at the top rather than a table somebody reads across.
///
/// **That number is never governed by the range control below it.** Today is
/// today; if the range changed it, the first question the owner ever asked would
/// silently become a different one. The range footer says so in one sentence.
///
/// WHAT IS DELIBERATELY NOT HERE
/// No chart, no sparkline, no trend line, no progress ring, no heat grid, no
/// shaded calendar, no streak, no badge, no best day, no personal record, no
/// goal, no comparison to last week, no percentage, no abandoned *rate*, and no
/// colour that encodes a value. `SPEC.md` puts gamification out of scope by
/// name, and a stats screen is where that pressure appears first. **If a number
/// wants emphasis it gets typography, not a graphic** — and the only number here
/// that gets emphasis is today's. There is no text field anywhere on it.
struct StatsScreen: View {
  // MARK: Internal

  let model: StatsScreenModel

  var body: some View {
    List {
      todaySection
      StatsRangeControl(model: model)
      lists
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    .safeAreaInset(edge: .bottom) { exportBar }
    // Keyed on the answer itself, so the file is rewritten when the range moves
    // and at no other time. `StatsPeriod` is `Equatable` precisely so this can
    // be written without a second flag to keep in step.
    .task(id: model.rangePeriod) { refreshExport() }
    .sheet(item: $openDay) { open in
      StatsDaySheet(day: open.day, entries: open.entries)
    }
  }

  // MARK: Private

  /// Half the loudness of the numeral that runs on the timer screen. Derived
  /// rather than stated, because `Typography` holds the app's *one* raw point
  /// size — and a 96-point number here would read as a second timer.
  private static let todayNumeralRatio: CGFloat = 0.5

  /// A day whose sentences are on screen.
  private struct OpenDay: Identifiable {
    let id: String
    let day: StatsDay
    let entries: [StatsDistractionEntry]
  }

  @ScaledMetric(relativeTo: .largeTitle) private var todayNumeralSize =
    Typography.numeralBaseSize * StatsScreen.todayNumeralRatio

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @State private var openDay: OpenDay?

  @State private var exportURL: URL?

  @State private var exportFailed = false

  private var todaySection: some View {
    Section {
      VStack(spacing: Spacing.sm) {
        Text(StatsScreenModel.todayKicker)
          .font(Typography.kicker)
          .textCase(.uppercase)
          // The one piece of colour on this screen.
          .foregroundStyle(Color(.action))
          .accessibilityHidden(true)

        Text(model.todayNumeral)
          .font(Typography.timerNumeral(size: todayNumeralSize))
          .tracking(todayNumeralSize * Typography.numeralTrackingRatio)
          .foregroundStyle(Color(model.todayIsAReading ? .textPrimary : .textSubtle))
          .lineLimit(1)
          .minimumScaleFactor(0.5)

        VStack(spacing: Spacing.xxs) {
          Text(model.todayUnitLine)
          if let tally = model.todayTallyLine {
            Text(tally)
          }
        }
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, Spacing.lg)
      // Page, not card: section zero reads as the top of a page rather than as
      // the first of four blocks.
      .listRowBackground(Color(.surfacePrimary))
      .listRowSeparator(.hidden)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(StatsScreenModel.todaySpokenLabel))
      .accessibilityValue(Text(model.todaySpoken))
    }
  }

  @ViewBuilder
  private var lists: some View {
    if model.rangeIsEmpty {
      emptySection
    } else {
      section(StatsScreenModel.daysHeader, model.dayRows)
      section(StatsScreenModel.projectsHeader, model.projectRows)
      section(StatsScreenModel.tasksHeader, model.taskRows)
    }
  }

  private var emptySection: some View {
    Section {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        Text(StatsScreenModel.emptyHeading(for: model.range))
          .font(Typography.title)
          .foregroundStyle(Color(.textPrimary))
        Text(StatsScreenModel.emptyDetail)
          .font(Typography.body)
          .foregroundStyle(Color(.textPrimary))
        Text(StatsScreenModel.emptyOrigin)
          .font(Typography.body)
          .foregroundStyle(Color(.textMuted))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, Spacing.xl)
      .listRowBackground(Color(.surfacePrimary))
      .listRowSeparator(.hidden)
    }
  }

  /// The bar along the bottom. A labelled button rather than a share glyph: it
  /// states the exact span leaving the app, and it is a thumb reach.
  ///
  /// **Quiet emphasis, not filled** —
  /// a filled sage button would be a second claim on the app's one colour and
  /// would advertise exporting as the main thing to do on a screen whose main
  /// thing is a number. The space is reserved in every state (D19).
  private var exportBar: some View {
    VStack(spacing: Spacing.none) {
      Rectangle()
        .fill(Color(.border))
        .frame(height: Spacing.borderHairline)

      if exportFailed {
        Text(StatsScreenModel.exportUnavailable)
          .font(Typography.label)
          .foregroundStyle(Color(.warningText))
          .multilineTextAlignment(.center)
          .padding(.horizontal, Spacing.md)
          .padding(.top, Spacing.sm)
      }

      exportControl
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
    .background(Color(.surfacePrimary))
  }

  @ViewBuilder
  private var exportControl: some View {
    if let exportURL {
      ShareLink(item: exportURL, preview: SharePreview(model.sharePreviewTitle)) {
        Text(model.exportButtonTitle)
      }
      .buttonStyle(SecondaryButtonStyle())
      .accessibilityLabel(Text(model.exportSpokenTitle))
      .accessibilityHint(Text(StatsScreenModel.exportHint))
    } else {
      // Drawn and switched off rather than absent, so the bar does not change
      // height under a thumb the instant the file lands.
      Button(model.exportButtonTitle) { }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(true)
        .accessibilityLabel(Text(model.exportSpokenTitle))
    }
  }

  private func section(_ title: String, _ rows: [StatsScreenModel.Row]) -> some View {
    Section {
      ForEach(rows) { row in
        listRow(row)
      }
      .listRowBackground(Color(.surfaceRaised))
    } header: {
      Text(title)
        .font(Typography.kicker)
        .textCase(.uppercase)
        .foregroundStyle(Color(.textMuted))
    }
  }

  /// The chevron appears **only** on rows that are actually tappable. A day with
  /// nothing behind it is not a dead button — it is not a button.
  @ViewBuilder
  private func listRow(_ row: StatsScreenModel.Row) -> some View {
    if row.isOpenable, let day = row.day {
      Button {
        openDay = OpenDay(id: row.id, day: day, entries: model.entries(on: day))
      } label: {
        rowBody(row, showsChevron: true)
      }
      .buttonStyle(.plain)
      .accessibilityHint(Text(StatsScreenModel.openDayHint))
      .accessibilityAddTraits(.isButton)
    } else {
      rowBody(row, showsChevron: false)
    }
  }

  private func rowBody(_ row: StatsScreenModel.Row, showsChevron: Bool) -> some View {
    rowLayout {
      VStack(alignment: .leading, spacing: Spacing.xxs) {
        // WRAPS, NEVER SHRINKS. A truncated task title is a wrong record on
        // screen, and this screen's whole job is to be trusted.
        Text(row.title)
          .font(Typography.body)
          .foregroundStyle(Color(row.titleIsAbsence ? .textMuted : .textPrimary))
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)

        Text(row.secondLine)
          .font(Typography.data)
          .foregroundStyle(Color(.textMuted))
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: Spacing.xs) {
        Text(row.count)
          // Monospaced, right-aligned, at a fixed minimum width: a column of
          // counts is readable straight down. Never coloured, never filled,
          // never given a bar behind it.
          .font(Typography.data)
          .foregroundStyle(Color(.textPrimary))
          .frame(minWidth: Spacing.xl, alignment: .trailing)

        if showsChevron {
          Image(systemName: "chevron.right")
            .font(Typography.label)
            .foregroundStyle(Color(.textMuted))
            .accessibilityHidden(true)
        }
      }
    }
    .frame(minHeight: Spacing.controlHeight)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(row.spokenTitle))
    .accessibilityValue(Text(row.spokenValue))
  }

  /// At the accessibility sizes the count moves under the title, as
  /// `DistractionButtons` already stacks.
  private var rowLayout: AnyLayout {
    dynamicTypeSize >= .accessibility1
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.sm))
  }

  private func refreshExport() {
    guard model.rangePeriod != nil else {
      exportURL = nil
      return
    }
    do {
      exportURL = try StatsExportFile.write(document: model.document, filename: model.filename)
      exportFailed = false
    } catch {
      exportURL = nil
      exportFailed = true
    }
  }
}

// MARK: - Finding a day's taps

extension StatsScreenModel {
  /// That day's taps, for the sheet behind a day row.
  ///
  /// A lookup, not a query: the taps are already on the period this screen is
  /// drawing, which is why the sheet and the export's by-task grouping are two
  /// views of one array rather than two arrays.
  func entries(on day: StatsDay) -> [StatsDistractionEntry] {
    rangePeriod?.days.first { $0.day == day }?.distractions ?? []
  }
}

// MARK: - Previews

#Preview("A fortnight, light") {
  StatsScreen(model: StatsPreview.model())
    .preferredColorScheme(.light)
}

/// With the light preview above: a fixed colour would make these two identical.
#Preview("A fortnight, dark") {
  StatsScreen(model: StatsPreview.model())
    .preferredColorScheme(.dark)
}

#Preview("A fortnight, largest text") {
  StatsScreen(model: StatsPreview.model()).dynamicTypeSize(.accessibility5)
}

/// A first morning, and also four hundred pomodoros with February chosen.
#Preview("Nothing in these days") {
  StatsScreen(model: StatsPreview.model(empty: true)).preferredColorScheme(.light)
}

#Preview("Nothing in these days, dark") {
  StatsScreen(model: StatsPreview.model(empty: true)).preferredColorScheme(.dark)
}

#Preview("Nothing in these days, largest text") {
  StatsScreen(model: StatsPreview.model(empty: true)).dynamicTypeSize(.accessibility5)
}

// MARK: - StatsPreview

/// A fortnight, by hand, for the previews. Never part of what ships, and not the
/// golden-file fixture — that one lives in the test bundle and is far longer.
private enum StatsPreview {
  /// `@MainActor` because `StatsScreenModel` is: it is the same type the app
  /// builds, handed a finished period instead of a database.
  @MainActor
  static func model(empty: Bool = false) -> StatsScreenModel {
    let model = StatsScreenModel(
      periods: { asked in empty ? StatsPeriod.empty(for: asked) : fortnight },
      today: wednesday)
    model.load()
    return model
  }

  // MARK: Private

  private static let wednesday = StatsDay(year: 2026, month: 8, day: 19, weekday: 4)
  private static let thursday = StatsDay(year: 2026, month: 8, day: 20, weekday: 5)

  private static let taps = [
    tap(hour: 14, minute: 32, kind: .internalInterruption, note: "kept re-reading the same paragraph"),
    tap(hour: 14, minute: 41, kind: .externalInterruption, note: "roommate came in"),
    tap(hour: 16, minute: 5, kind: .internalInterruption, note: nil)
  ]

  private static let fortnight = StatsPeriod(
    range: StatsRange(first: StatsDay(year: 2026, month: 8, day: 6, weekday: 5), last: thursday),
    days: [
      StatsDayRow(day: wednesday, pomodoroCount: 6, focusedSeconds: 9000, distractions: taps),
      // A day with nothing behind it: no chevron, and not a button.
      StatsDayRow(day: thursday, pomodoroCount: 4, focusedSeconds: 6000, distractions: [])
    ],
    projects: [
      StatsProjectRow(
        title: "Thesis",
        tasks: [
          StatsTaskRow(
            title: "Ch.3 draft", projectTitle: "Thesis", pomodoroCount: 14,
            focusedSeconds: 21_000, internalCount: 5, externalCount: 3),
          // A block worked under the project with no task chosen: the plain
          // "No task" wording is visible in a preview rather than only in a
          // fortnight nobody has yet.
          StatsTaskRow(
            title: nil, projectTitle: "Thesis", pomodoroCount: 4,
            focusedSeconds: 6000, internalCount: 1, externalCount: 0)
        ]),
      StatsProjectRow(
        title: nil,
        tasks: [
          StatsTaskRow(
            title: "Reading", projectTitle: nil, pomodoroCount: 2,
            focusedSeconds: 3000, internalCount: 1, externalCount: 1)
        ])
    ],
    completions: [StatsCompletion(day: wednesday, title: "Ch.3 draft", wasRecurring: false)],
    stops: [])

  private static func tap(
    hour: Int,
    minute: Int,
    kind: DistractionKind,
    note: String?) -> StatsDistractionEntry {
    StatsDistractionEntry(
      day: wednesday,
      time: StatsClockTime(hour: hour, minute: minute),
      kind: kind,
      note: note,
      taskTitle: "Ch.3 draft",
      projectTitle: "Thesis")
  }
}
