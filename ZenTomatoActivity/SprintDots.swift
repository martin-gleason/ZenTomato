import SwiftUI

/// How far through the sprint you are, as it appears on the Lock Screen and in
/// the Dynamic Island: `2 OF 4`.
///
/// A NOTE ON THIS FILE'S NAME
/// The build contract calls this file `SprintDots.swift`, because the first sketch
/// of the Live Activity drew the sprint as a row of dots — the same idea as the
/// segmented rule on the app's own timer screen. The design review replaced the
/// dots with these four characters before any code was written, and the file kept
/// its contract name so that the two documents still line up. Three reasons the
/// dots lost, all of them about the size of the card they had to fit on:
///
///   1. The Lock Screen card is about sixty points tall. A row of dots inside it
///      is texture rather than information.
///   2. A sprint may be twelve pomodoros long. Twelve dots across a Lock Screen
///      card are slivers, and counting slivers is precisely the work a glanceable
///      indicator exists to save.
///   3. `2 OF 4` reads correctly to VoiceOver with no extra description, because
///      it is already words.
///
/// The app's timer screen keeps the rule, because it has a whole screen to draw
/// it on. Two surfaces, two forms, the same fact — that is sizing information to
/// the space it has, not an inconsistency.
struct SprintCount: View {
  // MARK: Internal

  /// How many focus blocks of this sprint are finished. Skipped blocks are not
  /// finished blocks and are not counted here.
  let completed: Int

  /// How many focus blocks make up the sprint.
  let total: Int

  var body: some View {
    Text("\(completed) of \(total)")
      .font(Typography.kicker)
      .textCase(.uppercase)
      .foregroundStyle(Color(.textMuted))
      // One line, and it is the first thing allowed to disappear if the card is
      // too narrow — see `BlockLiveActivity`, where it is given the lowest layout
      // priority. Dropping it entirely is better than clipping it: half a
      // fraction is worse than no fraction.
      .lineLimit(1)
  }
}

// MARK: - Previews

/// The three cases worth looking at: a normal sprint, the widest one the
/// settings allow, and a sprint of one.
#Preview("Light") {
  SprintCountPreviewRows()
    .preferredColorScheme(.light)
}

/// The Dynamic Island is always drawn on black, so the dark values are the ones
/// that appear there. Both are checked.
#Preview("Dark") {
  SprintCountPreviewRows()
    .preferredColorScheme(.dark)
}

/// Preview scaffolding, never built into anything that ships.
private struct SprintCountPreviewRows: View {
  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      SprintCount(completed: 2, total: 4)
      SprintCount(completed: 11, total: 12)
      SprintCount(completed: 0, total: 1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(Spacing.md)
    .background(Color(.surfacePrimary))
  }
}
