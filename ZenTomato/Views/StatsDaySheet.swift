import SwiftUI

/// One day's interruptions, in the order they happened.
///
/// WHY THIS IS THE ONLY THING BEHIND A DAY ROW
/// The sentences are the point of the log. `SPEC.md` says the app's unique value
/// is the distraction record — *"Self-Knowledge data, tallied in the moment and
/// readable at the two-week Rhodia review"* — and this is the one place on glass
/// where you re-read an afternoon rather than count it.
///
/// **Stops are not shown here.** `F6.md` defines this gesture as *"shows that
/// day's distraction sentences"*, and D15's whole argument is that a stop is a
/// decision and a distraction is a moment. Mixing them under one tap would put
/// them back in the list D15 took them out of. Stops live in the export's own
/// section.
///
/// **Nothing here is editable.** There is no text field on this sheet, no
/// annotation, no search over the log. The one place a sentence is written is
/// the end-of-block sheet, at the moment the block ends, when the memory is an
/// hour old rather than a fortnight.
struct StatsDaySheet: View {
  // MARK: Internal

  let day: StatsDay

  /// That day's taps. Given rather than fetched: this sheet has no store, no
  /// query and nothing to count.
  let entries: [StatsDistractionEntry]

  // Every sentence this sheet can say, gathered here rather than written inline.
  // `NoCaptureSurfaceTests` reads them, which is only possible because they are
  // named — a string typed into a view is a string outside the pattern the
  // no-capture rule is checked by.

  static let header = "What interrupted this day"
  static let internalWord = "Internal"
  static let externalWord = "External"

  /// **A skipped note reads `No note`, never a blank line.** The tap is data —
  /// somebody noticed the interruption and only declined to describe it — and
  /// the number of lines on this sheet has to agree with the `3 internal ·
  /// 1 external` on the row that opened it. A blank would make two numbers on
  /// one screen disagree, which is how a number stops being trusted.
  static let noNote = "No note"

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
            row(line)
          }
        } header: {
          Text(Self.header)
            .font(Typography.kicker)
            .textCase(.uppercase)
            .foregroundStyle(Color(.textMuted))
        }
        .listRowBackground(Color(.surfaceRaised))
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(Color(.surfacePrimary).ignoresSafeArea())
      .navigationTitle(StatsWords.date(day))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(StatsScreenModel.doneLabel) { dismiss() }
        }
      }
    }
  }

  // MARK: Private

  /// One line of the sheet: a time, a word, and a sentence.
  private struct Line {
    let time: String
    let kind: String
    let sentence: String
    let hasNote: Bool
    let spokenTime: String
  }

  @Environment(\.dismiss) private var dismiss

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// Chronologically ascending: you are re-walking the afternoon.
  private var lines: [Line] {
    entries
      .sorted { $0.time < $1.time }
      .map { entry in
        let written = StatsWords.clean(entry.note ?? "")
        return Line(
          time: StatsWords.time(entry.time),
          // The word, never a bold `I` and never a coloured chip. One
          // vocabulary across the screen, the tally and the paper — and no
          // colour is spent here at all, because the kind is carried by the
          // word.
          kind: entry.kind == .internalInterruption ? Self.internalWord : Self.externalWord,
          sentence: written.isEmpty ? Self.noNote : written,
          hasNote: written.isEmpty == false,
          spokenTime: StatsWords.time(entry.time))
      }
  }

  /// At the accessibility text sizes the time moves onto its own line above the
  /// word, exactly as `DistractionButtons` already stacks.
  private var layout: AnyLayout {
    dynamicTypeSize >= .accessibility1
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.sm))
  }

  private func row(_ line: Line) -> some View {
    layout {
      Text(line.time)
        // Monospaced, so a column of times lines up straight down.
        .font(Typography.data)
        .foregroundStyle(Color(.textSubtle))
        .frame(minWidth: Spacing.xxl, alignment: .leading)

      VStack(alignment: .leading, spacing: Spacing.xxs) {
        Text(line.kind)
          .font(Typography.kicker)
          .textCase(.uppercase)
          .foregroundStyle(Color(.textMuted))

        Text(line.sentence)
          .font(Typography.body)
          .foregroundStyle(Color(line.hasNote ? .textPrimary : .textSubtle))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(minHeight: Spacing.controlHeight)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("\(line.spokenTime), \(line.kind.lowercased())"))
    .accessibilityValue(Text(line.sentence))
  }
}

// MARK: - Previews

#Preview("A day's interruptions, light") {
  StatsDaySheet(day: DaySheetPreview.day, entries: DaySheetPreview.taps)
    .preferredColorScheme(.light)
}

#Preview("A day's interruptions, dark") {
  StatsDaySheet(day: DaySheetPreview.day, entries: DaySheetPreview.taps)
    .preferredColorScheme(.dark)
}

#Preview("A day's interruptions, largest text") {
  StatsDaySheet(day: DaySheetPreview.day, entries: DaySheetPreview.taps)
    .dynamicTypeSize(.accessibility5)
}

/// One afternoon, by hand. Never part of what ships.
///
/// It deliberately includes a tap with no sentence, because `No note` is the one
/// line on this sheet that somebody would otherwise be tempted to hide.
private enum DaySheetPreview {
  static let day = StatsDay(year: 2026, month: 8, day: 19, weekday: 4)

  static let taps = [
    tap(hour: 14, minute: 32, kind: .internalInterruption, note: "kept re-reading the same paragraph"),
    tap(hour: 14, minute: 41, kind: .externalInterruption, note: "roommate came in"),
    tap(hour: 16, minute: 5, kind: .internalInterruption, note: nil)
  ]

  private static func tap(hour: Int, minute: Int, kind: DistractionKind, note: String?)
    -> StatsDistractionEntry {
    StatsDistractionEntry(
      day: day,
      time: StatsClockTime(hour: hour, minute: minute),
      kind: kind,
      note: note,
      taskTitle: "Ch.3 draft",
      projectTitle: "Thesis")
  }
}
