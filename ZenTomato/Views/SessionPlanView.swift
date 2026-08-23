import SwiftUI

/// The session plan: what you meant to work on, in the order you meant to work
/// it, with one cursor showing where the timer has got to.
///
/// THERE IS NO REFRESH CONTROL ON THIS SCREEN, AND THAT IS DELIBERATE
/// The picker pulls to refresh; this does not. **The plan does not chase
/// Todoist.** The snapshot titles exist precisely so that it does not have to,
/// and a plan that re-read itself would be a plan whose contents could change
/// under a finger.
///
/// THERE IS NO WAY TO CHANGE THE ORDER HERE EITHER
/// D17 says the order is the user's, *set when the plan is built*, and the build
/// contract spells out that there is no reordering after the fact and no
/// appending to a plan in progress. Changing your mind means building a new
/// plan in the picker, which replaces this one — and what actually happened is
/// already recorded on the finished-block rows, so nothing is lost by it.
///
/// WHAT CAN BE DONE HERE
/// Two things, both of which only ever shorten the queue or move past it:
/// **Skip**, which moves the cursor on without touching the item, and
/// **Remove**, which takes an item out. Neither writes anything to Todoist.
struct SessionPlanView: View {
  // MARK: Internal

  let plan: SessionPlanStore

  /// Finish with the whole sheet.
  let onDone: () -> Void

  var body: some View {
    content
      .navigationTitle(PickerScreenModel.sessionPlanTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { onDone() }
            .accessibilityHint(Text("Closes."))
        }
      }
      .onChange(of: failureNote) { _, note in
        guard let note else { return }
        AccessibilityNotification.Announcement(note).post()
      }
  }

  // MARK: Private

  /// Shown when a change could not be written down.
  ///
  /// **This screen's one amber thing.** A plan change that silently did not
  /// happen would leave somebody looking at a queue the timer is not going to
  /// follow, which is worse than saying so.
  private static let changeFailed = "That change wasn't saved. Try again."

  @State private var failureNote: String?

  private var rows: [SessionPlanScreenModel.Row] {
    SessionPlanScreenModel.rows(
      items: plan.items,
      currentIndex: plan.currentIndex,
      completions: plan.completionsRecorded(),
      planCreatedAt: plan.createdAt,
      isStillInTodoist: { plan.isStillInTodoist($0) })
  }

  @ViewBuilder
  private var content: some View {
    if plan.isEmpty {
      emptyPlan
    } else {
      list
    }
  }

  private var list: some View {
    List {
      if let failureNote {
        Section {
          failureRow(failureNote)
        }
        .listRowBackground(Color(.surfaceRaised))
      }

      Section {
        ForEach(rows) { row in
          PlanRowView(
            row: row,
            onStepOver: { record(plan.stepOver()) },
            onRemove: { record(plan.remove(row.item)) })
        }
      } header: {
        Text(PickerScreenModel.inOrderHeader)
          .font(Typography.kicker)
          .textCase(.uppercase)
          .foregroundStyle(Color(.textMuted))
      }
      .listRowBackground(Color(.surfaceRaised))
    }
    .scrollContentBackground(.hidden)
    .background(Color(.surfacePrimary).ignoresSafeArea())
  }

  /// Only reachable by removing every item while standing on this screen.
  ///
  /// **No button.** Back is the way to the picker, and the picker is the only
  /// place a plan is built — which is what removes the need for an "Add"
  /// control anywhere in this navigation stack.
  private var emptyPlan: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      Text(PickerScreenModel.emptyPlanHeading)
        .font(Typography.title)
        .foregroundStyle(Color(.textPrimary))
        .accessibilityAddTraits(.isHeader)

      Text(PickerScreenModel.emptyPlanDetail)
        .font(Typography.body)
        .foregroundStyle(Color(.textMuted))
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(.horizontal, Spacing.md)
    .padding(.vertical, Spacing.xl)
    .background(Color(.surfacePrimary).ignoresSafeArea())
  }

  private func failureRow(_ message: String) -> some View {
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

  private func record(_ written: Bool) {
    failureNote = written ? nil : Self.changeFailed
  }
}
