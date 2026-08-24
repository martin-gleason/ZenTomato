import SwiftUI

/// The two dates the lists and the export cover, and a way back to the
/// fortnight.
///
/// **Two pickers and a reset. No presets.** A row of `Today / 7 / 14 / 30`
/// buttons is one afternoon away from `This week vs last week`, and a comparison
/// is a score — which `SPEC.md` puts out of scope by name. Two dates cannot
/// compare anything; they can only say which days you are looking at.
///
/// **There is no validation, because there is nothing to validate.** The bounds
/// *are* the control: the start picker cannot go past the end, and the end
/// picker cannot go before the start or past today. So there is no swapped-dates
/// case, no error state, no alert copy, and no way to sit looking at an empty
/// screen you caused. `SettingsView.minutesRow` already makes this argument for
/// the six timer values, and it is the same argument.
///
/// **The selection is not persisted.** It returns to the trailing fortnight
/// every time the screen opens. That is correct — a range is a question you are
/// asking now, not a setting — and it is also required: remembering it would
/// mean a seventh `AppSettings` field, and `AppSettings` gains zero changed
/// lines in this feature.
struct StatsRangeControl: View {
  // MARK: Internal

  let model: StatsScreenModel

  var body: some View {
    Section {
      if let start, let end, let todayInstant {
        DatePicker(
          StatsScreenModel.rangeStartLabel,
          selection: binding(for: start, movingTheStart: true),
          in: ...end,
          displayedComponents: .date)

        DatePicker(
          StatsScreenModel.rangeEndLabel,
          selection: binding(for: end, movingTheStart: false),
          in: start...todayInstant,
          displayedComponents: .date)
      }

      // Always drawn, including when the two pickers above could not be built.
      // The way back to the default must not depend on the thing that failed.
      Button(StatsScreenModel.rangeResetLabel) { model.resetRange() }
        .font(Typography.body)
        .accessibilityHint(Text(StatsScreenModel.rangeHint))
    } header: {
      Text(StatsScreenModel.rangeHeader)
        .font(Typography.kicker)
        .textCase(.uppercase)
        .foregroundStyle(Color(.textMuted))
    } footer: {
      Text(model.rangeFooter)
        .font(Typography.body)
        .foregroundStyle(Color(.textMuted))
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  // MARK: Private

  /// The instants the two pickers sit on.
  ///
  /// Optional because building a date from a year, a month and a day can fail in
  /// principle, and a force unwrap here would trade an unreachable branch for a
  /// crash. When either is missing the pickers are not drawn and the reset
  /// button is, which is the smallest honest degradation available.
  private var start: Date? { model.instant(for: model.range.first) }

  private var end: Date? { model.instant(for: model.range.last) }

  private var todayInstant: Date? { model.instant(for: model.today) }

  /// A binding whose setter goes through the model, so that moving a date and
  /// re-running the query are one movement rather than two that could disagree.
  private func binding(for value: Date, movingTheStart: Bool) -> Binding<Date> {
    Binding(
      get: { value },
      set: { picked in
        let day = model.day(for: picked)
        model.use(range: movingTheStart
          ? StatsRange(first: day, last: model.range.last)
          : StatsRange(first: model.range.first, last: day))
      })
  }
}
