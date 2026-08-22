import SwiftUI

/// Shown instead of the timer when the app cannot open its own database.
///
/// **Why this screen exists.** Everything ZenTomato remembers — the block
/// lengths, and later the history — lives in a small database file on the phone.
/// Opening it is the first thing the app does, and it can fail: the device can be
/// out of storage, the file can be damaged, or iOS can refuse access while the
/// phone is still locked after a restart.
///
/// The alternative to this screen is the app closing instantly with no
/// explanation, which is what happens by default. That is the worst possible
/// outcome for the person holding the phone: no message, no cause, and nothing to
/// try. One plain-English screen is a much better trade, and it is the reason
/// there is no crash-on-purpose shortcut anywhere in this codebase.
///
/// **There is nothing to tap here on purpose.** Reopening the database needs the
/// app to start again from scratch, which is exactly what quitting and reopening
/// does — so a "Try again" button would either lie or do nothing. The screen says
/// what to do instead.
struct StoreUnavailableView: View {
  // MARK: Internal

  /// The system's own description of what went wrong.
  ///
  /// Shown deliberately, in small print, below the explanation. It is written for
  /// a developer rather than for a reader, but if this ever happens it is the
  /// only clue anyone will have, and hiding it helps nobody.
  let technicalDetail: String

  var body: some View {
    // Scrolls rather than clips, because at the largest accessibility text sizes
    // this much text is taller than a phone screen. `.basedOnSize` means it only
    // behaves like a scrolling view when it actually needs to.
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.md) {
        Text("Problem")
          .font(Typography.kicker)
          .textCase(.uppercase)
          .foregroundStyle(Color(.dangerText))
          // VoiceOver is given the word in its ordinary case. Some screen
          // readers spell an all-capitals string out letter by letter, and
          // "P-R-O-B-L-E-M" ahead of the explanation would be a poor start on
          // the one screen a person only ever reaches when something is already
          // wrong. The timer screen solves the same problem the same way.
          .accessibilityLabel(Text("Problem"))

        Text("ZenTomato can't open its saved data")
          .font(Typography.title)
          .foregroundStyle(Color(.textPrimary))

        Text(
          """
          The app keeps your timer settings in a small file on this phone, and it \
          could not open that file just now.
          """)
          .font(Typography.body)
          .foregroundStyle(Color(.textPrimary))

        Text(
          """
          Close ZenTomato completely and open it again. If it keeps happening, \
          check that the phone is not out of storage. Removing and reinstalling \
          the app will clear the file and fix it, at the cost of resetting your \
          timer lengths back to their defaults.
          """)
          .font(Typography.body)
          .foregroundStyle(Color(.textMuted))

        Text(technicalDetail)
          .font(Typography.data)
          .foregroundStyle(Color(.textSubtle))
          // Marked as a technical detail so VoiceOver announces it as such
          // rather than reading it as if it were part of the advice above.
          .accessibilityLabel(Text("Technical detail"))
          .accessibilityValue(Text(technicalDetail))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Spacing.md)
      .padding(.vertical, Spacing.xl)
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.surfacePrimary).ignoresSafeArea())
  }
}

// MARK: - Previews

#Preview("Light") {
  StoreUnavailableView(technicalDetail: "The file couldn't be opened because there is no such file.")
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  StoreUnavailableView(technicalDetail: "The file couldn't be opened because there is no such file.")
    .preferredColorScheme(.dark)
}
