import SwiftUI

/// How far through the sprint you are, on the timer screen.
///
/// ```
/// ███████ ███████ ░░░░░░░ ░░░░░░░      2 of 4 done
/// ```
///
/// A single hairline rule across the width of the screen, cut into one segment
/// per pomodoro. A finished pomodoro fills its segment.
///
/// WHY A RULE AND NOT DOTS
/// Dots are the obvious answer and they lose on three counts here. A sprint can
/// be twelve pomodoros long, and twelve dots read as a texture that has to be
/// *counted* — which is exactly the work a glanceable indicator exists to save.
/// A dot has mass, so twelve of them under the countdown become a second thing
/// competing for attention and a second claim on the app's one colour; a
/// two-point rule has no mass at any width and reads as structure, like the line
/// under a headline. And a full-width rule says "this is the shape of your
/// sprint" at a glance, which a scattering of dots does not.
///
/// A FINISHED SEGMENT IS TALLER AS WELL AS GREENER, AND THAT IS NOT DECORATION
/// The two inks this rule is drawn in — the app's sage and its strong grey —
/// are both chosen to stand out against the *page*, and they do. Measured
/// against **each other** they are 1.37:1 in light and 1.39:1 in dark: two
/// colours of almost exactly the same lightness. On a two-point rule that reads
/// as one unbroken line, so a person who is not looking for the boundary cannot
/// see it, and a person who does not distinguish those hues never could. The
/// accessibility standard asks for 3:1 between anything you have to tell apart
/// and forbids carrying information by colour alone; this failed both.
///
/// Repainting one of them was not the answer — every other pairing in the token
/// table either loses its contrast against the page or spends the app's one
/// colour somewhere it does not belong. So the distinction is carried by shape
/// instead: a finished segment is twice as tall as an unfinished one and the
/// row is aligned along its bottom edge, which gives the rule a visible step at
/// the boundary in any appearance, at any colour vision, and in a photograph.
/// The colours stay as the design intended and are now the second signal rather
/// than the only one.
///
/// TWO STATES, NOT THREE
/// A segment is either finished or it is not. The block that is *running* is
/// given no third appearance, because it does not need one: the word above the
/// countdown names it and the countdown is visibly moving. Asking a two-point
/// line to carry a distinction that two much louder elements already carry would
/// be asking too much of it.
///
/// A consequence worth stating so it is not read as a bug: during the third focus
/// block of four the rule shows two filled segments, and during the short break
/// that follows it shows three. The rule counts *finished* pomodoros. A skipped
/// block is abandoned and never fills a segment — the same rule the saved records
/// follow, so the screen and the history cannot disagree about what a pomodoro is.
struct SprintProgressView: View {
  // MARK: Internal

  /// How many pomodoros of this sprint are finished.
  let completed: Int

  /// How many pomodoros make up the sprint. Between 1 and 12.
  let total: Int

  /// How tall a finished segment is drawn. Twice the height of an unfinished
  /// one, which is what makes the boundary between them visible without relying
  /// on the difference between two colours.
  static let filledHeight = Spacing.xxs

  /// How tall an unfinished segment is drawn: the hairline the design asks for.
  static let emptyHeight = Spacing.xxxs

  var body: some View {
    Group {
      if dynamicTypeSize >= .accessibility1 {
        countedInWords
      } else {
        rule
      }
    }
    // Both forms carry the identical spoken label and value, so a VoiceOver
    // user's experience does not change at the size boundary above.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Sprint progress"))
    .accessibilityValue(Text("\(completed) of \(total) pomodoros done"))
  }

  // MARK: Private

  /// How far the words may shrink before they would overflow. Eleven characters
  /// at the largest accessibility size hold one line on a phone with room to
  /// spare, so this floor is a guard rather than a working value.
  private static let minimumScale: CGFloat = 0.7

  /// The reader's chosen text size.
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// The hairline form, used at ordinary text sizes.
  private var rule: some View {
    // Bottom-aligned, so the two heights share a baseline and the extra height
    // of a finished segment grows upwards as a step rather than as a thicker
    // line floating in the middle of the row.
    HStack(alignment: .bottom, spacing: Spacing.xxxs) {
      ForEach(0..<max(total, 1), id: \.self) { index in
        let isFinished = index < completed
        Rectangle()
          .fill(isFinished ? Color(.action) : Color(.borderStrong))
          .frame(height: isFinished ? Self.filledHeight : Self.emptyHeight)
      }
    }
    .frame(height: Self.filledHeight, alignment: .bottom)
    // Square corners: the sharpest thing in an app whose corners are already
    // sharper than the platform's.
    .clipShape(RoundedRectangle(cornerRadius: Radius.none))
  }

  /// The words form, used at the accessibility text sizes.
  ///
  /// **The rule is replaced here rather than shrunk or supplemented, and that is
  /// the whole point.** Gaps and stroke widths in this design system deliberately
  /// do not grow with the reader's text size — Apple's own apps work that way,
  /// and scaling the margins as well as the type pushes content off the screen.
  /// But a reader at these sizes has told the system their vision needs help, and
  /// a two-point line ignores that no matter what shape it is. Text is the only
  /// form of this information that grows along with everything else around it.
  ///
  /// `2 of 4 done` rather than `pomodoro 2 of 4`, because the second is ambiguous
  /// — is that the second one, or two finished? — and it is twice as wide at
  /// exactly the size where width is the constraint.
  private var countedInWords: some View {
    Text("\(completed) of \(total) done")
      .font(Typography.kicker)
      .textCase(.uppercase)
      .foregroundStyle(Color(.textMuted))
      .lineLimit(1)
      .minimumScaleFactor(Self.minimumScale)
      .frame(maxWidth: .infinity)
  }
}

// MARK: - Previews

#Preview("Light") {
  SprintProgressPreviewRows()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  SprintProgressPreviewRows()
    .preferredColorScheme(.dark)
}

/// The size at which the rule becomes words, at the widest sprint the settings
/// allow. This is the case the swap exists for.
#Preview("Largest text") {
  SprintProgressPreviewRows()
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships.
private struct SprintProgressPreviewRows: View {
  var body: some View {
    VStack(spacing: Spacing.xl) {
      SprintProgressView(completed: 0, total: 4)
      SprintProgressView(completed: 2, total: 4)
      SprintProgressView(completed: 4, total: 4)
      SprintProgressView(completed: 11, total: 12)
      SprintProgressView(completed: 0, total: 1)
    }
    .padding(.horizontal, Spacing.md)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.surfacePrimary))
  }
}
