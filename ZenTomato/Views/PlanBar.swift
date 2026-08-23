import SwiftUI

/// The line pinned along the bottom of the picker and of every project screen.
///
/// **When the plan is empty it is inert, and that is what removes the need for
/// an "Add" button anywhere on this sheet.** The plan is only ever reached from
/// the picker, so the way to put something in it is the picker you are already
/// standing in.
struct PlanBar: View {
  // MARK: Internal

  /// The two facts the bar draws.
  ///
  /// Deliberately *not* the list itself: the bar is fed either by the selection
  /// being built or by the plan already stored, and giving it a count and a
  /// title rather than a collection is what lets one view say both without
  /// knowing which it is looking at.
  struct Contents: Equatable {
    /// How many things are in the plan the bar is reporting.
    let count: Int

    /// The next one to be worked, or `nil` for a plan that has been worked
    /// through. A plan can have items and no next item; the bar then names the
    /// plan and stays tappable, because Skip and Remove are still in there.
    let nextTitle: String?

    /// Whether there is anything to open. Written as a floor rather than as a
    /// comparison with zero, so it reads as "at least one".
    var isEmpty: Bool { count < 1 }
  }

  let contents: Contents

  /// Tapping it opens the session plan. Only called when there is something in
  /// the plan to open.
  let onOpen: () -> Void

  var body: some View {
    content
      .padding(.horizontal, Spacing.md)
      .padding(.vertical, Spacing.xs)
      .frame(maxWidth: .infinity)
      .background(Color(.surfaceRaised))
      .overlay(alignment: .top) {
        // Decoration, and one of the few places the decorative border role is
        // correct. It carries no information, so VoiceOver is told to skip it.
        Rectangle()
          .fill(Color(.border))
          .frame(height: Spacing.borderHairline)
          .accessibilityHidden(true)
      }
  }

  // MARK: Private

  @ViewBuilder
  private var content: some View {
    if contents.isEmpty == false {
      Button(action: onOpen) {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
          Text(PickerScreenModel.planSummary(count: contents.count))
            .font(Typography.label)
            .foregroundStyle(Color(.textPrimary))
          if let nextTitle = contents.nextTitle {
            Text(PickerScreenModel.nextInPlan(nextTitle))
              .font(Typography.label)
              .foregroundStyle(Color(.textMuted))
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: Spacing.controlHeight)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityHint(Text("Opens your session plan."))
    } else {
      Text(PickerScreenModel.nothingPlannedYet)
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        .frame(maxWidth: .infinity)
        .frame(minHeight: Spacing.controlHeight)
    }
  }
}
