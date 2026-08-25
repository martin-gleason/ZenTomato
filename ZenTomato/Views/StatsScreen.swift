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

  /// A day whose sentences are on screen.
  private struct OpenDay: Identifiable {
    let id: String
    let day: StatsDay
    let entries: [StatsDistractionEntry]
  }

  /// The day's count, at the reader's text size. The magnitude is `Typography`'s
  /// to decide, not this screen's — see ``Typography/statNumeralBaseSize``.
  /// `relativeTo: .largeTitle` picks the growth curve that flattens off at the
  /// top accessibility sizes instead of running away.
  @ScaledMetric(relativeTo: .largeTitle) private var todayNumeralSize =
    Typography.statNumeralBaseSize

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

  /// Two states that look alike and mean opposite things — see
  /// `StatsScreenModel.unreadableHeading`.
  private var emptySection: some View {
    Section {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        Text(model.couldNotBeRead
          ? StatsScreenModel.unreadableHeading
          : StatsScreenModel.emptyHeading(for: model.range))
          .font(Typography.title)
          .foregroundStyle(Color(.textPrimary))
        Text(model.couldNotBeRead
          ? StatsScreenModel.unreadableDetail
          : StatsScreenModel.emptyDetail)
          .font(Typography.body)
          .foregroundStyle(Color(.textPrimary))
        if model.couldNotBeRead == false {
          // Only the empty state gets this: it answers "I did a block this
          // morning, why is it not here?", which the unreadable copy answers
          // already, and repeating it there would read as an excuse.
          Text(StatsScreenModel.emptyOrigin)
            .font(Typography.body)
            .foregroundStyle(Color(.textMuted))
        }
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
