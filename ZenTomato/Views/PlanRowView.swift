import SwiftUI

/// One row of the session plan: an ordinal, the snapshot title, and — when
/// there is something to say — one quiet line under it.
///
/// **NOTHING ELSE IS ON THIS ROW.** No project name, no due date, no chevron
/// into Todoist. A planned item holds a Todoist id and a title snapshot, so
/// anything else here would have to be fetched from the mirror — and would
/// therefore vanish the day the task did, which is the D17 fence made visible
/// rather than merely obeyed.
///
/// THE TITLE IS THE SNAPSHOT, ALWAYS
/// It is the string that was true when the plan was built, not a live lookup. A
/// task renamed in Todoist half way through a session must not silently change
/// what the plan says you meant to do, and a task deleted in Todoist must not
/// leave a blank row.
///
/// THE CURRENT ITEM CARRIES THREE SIGNALS, ONLY ONE OF WHICH IS COLOUR
/// A tinted ground, a heavy leading bar, and the word CURRENT. The word is the
/// non-colour signal, which matters here for the same reason the sprint rule
/// gives a finished segment extra height: the tint and the ordinary ground are
/// close in lightness.
struct PlanRowView: View {
  // MARK: Internal

  let row: SessionPlanScreenModel.Row

  /// Moves the cursor past the item at the front of the queue.
  let onStepOver: () -> Void

  /// Takes this item out of the plan. **Nothing in Todoist changes.**
  let onRemove: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: Spacing.sm) {
      currentBar
      leading
      titleBlock
      Spacer(minLength: Spacing.xs)
      if row.isCurrent {
        Text("Current")
          .font(Typography.kicker)
          .textCase(.uppercase)
          .foregroundStyle(Color(.action))
          .accessibilityHidden(true)
      }
    }
    .frame(minHeight: Spacing.controlHeight)
    .listRowBackground(Color(row.isCurrent ? .actionSubtle : .surfaceRaised))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(spokenLabel))
    // VOICEOVER GETS EVERY ACTION WITHOUT A SWIPE.
    //
    // Both of the gestures below are swipes, and a row whose only controls are
    // swipes is a row a VoiceOver reader cannot operate at all.
    .accessibilityActions {
      if row.isCurrent {
        Button("Skip this one") { onStepOver() }
      }
      Button("Remove from plan") { onRemove() }
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      if row.isCurrent {
        Button("Skip") { onStepOver() }
          .tint(Color(.textMuted))
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      // **NOT RED, AND NOT THE WORD "DELETE".** Nothing is deleted: a red
      // destructive swipe on a row that mirrors a Todoist task would read as
      // deleting the task in Todoist, which this app cannot do and must never
      // appear to.
      Button("Remove") { onRemove() }
        .tint(Color(.textMuted))
    }
  }

  // MARK: Private

  /// The heavy leading rule on the current row.
  @ViewBuilder
  private var currentBar: some View {
    Rectangle()
      .fill(Color(row.isCurrent ? .action : .surfaceRaised))
      .frame(width: Spacing.borderThick)
      .frame(maxHeight: .infinity)
      .accessibilityHidden(true)
  }

  /// The ordinal, or a tick where this app closed the task.
  @ViewBuilder
  private var leading: some View {
    switch row.state {
    case .completedHere:
      Image(systemName: "checkmark")
        .font(Typography.data)
        .foregroundStyle(Color(.action))
        .frame(width: Self.ordinalWidth, alignment: .trailing)
        .accessibilityHidden(true)
    case .planned, .gone:
      Text("\(row.item.position + 1)")
        .font(Typography.data)
        .foregroundStyle(Color(.textSubtle))
        // A fixed leading width, so the numbers line up down the list.
        .frame(width: Self.ordinalWidth, alignment: .trailing)
        .accessibilityHidden(true)
    }
  }

  private var titleBlock: some View {
    VStack(alignment: .leading, spacing: Spacing.xxs) {
      Text(row.item.titleSnapshot)
        .font(Typography.body)
        // **No strikethrough in any state.** See `SessionPlanScreenModel`.
        .foregroundStyle(Color(isHistory ? .textMuted : .textPrimary))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)

      if let note = row.note {
        Text(note)
          .font(Typography.label)
          .foregroundStyle(Color(.textMuted))
          .fixedSize(horizontal: false, vertical: true)
      }

      // A DEAD END NEEDS A VISIBLE WAY OUT.
      //
      // Every other row keeps the swipe and the accessibility action, which is
      // enough. The item at the front of the queue that is no longer in Todoist
      // is the one case where a hidden gesture would be cruel: the timer will
      // attach the next pomodoro to something that is not there, and the only
      // exit would be a gesture nobody was told about.
      if row.isCurrent, row.state == .gone {
        Button("Skip to the next one") { onStepOver() }
          .buttonStyle(SecondaryButtonStyle(emphasis: .normal))
          .padding(.top, Spacing.xs)
      }
    }
  }

  /// Whether this row is behind the cursor or already accounted for, and should
  /// therefore be drawn in the quieter ink.
  private var isHistory: Bool {
    row.isWorked || row.state != .planned
  }

  /// The whole row as one sentence, since the row is one element to VoiceOver.
  private var spokenLabel: String {
    var parts = ["\(row.item.position + 1). \(row.item.titleSnapshot)"]
    if row.isCurrent { parts.append("current") }
    if let note = row.note { parts.append(note) }
    return parts.joined(separator: ", ")
  }

  /// Wide enough for a two-digit ordinal at the largest text size. The plan is
  /// as long as somebody makes it; three digits would be an unusual afternoon.
  private static let ordinalWidth: CGFloat = Spacing.lg
}
