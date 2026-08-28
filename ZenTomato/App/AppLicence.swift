import Foundation

/// The licence text the app itself can show.
///
/// **THE GPL REQUIRES THIS.** Section 4: conveying the program requires giving
/// every recipient a copy of the licence along with it. A copy of the app is a
/// conveyance, and a licence file in the repository satisfies the repository —
/// not the app. So the notice travels *inside the binary*, and the About screen
/// is what puts it in front of somebody.
///
/// **Held as a constant rather than read from a bundled file** so it cannot be
/// silently absent: a missing resource is a runtime surprise, a missing constant
/// does not compile. `LicenceFenceTests` checks the words are really here.
enum AppLicence {
  /// What governs this app — everywhere, in every form.
  ///
  /// The GPL runs to thousands of words, so the app shows the licence notice and
  /// links the full text at the source repository, which the GPL's own "How to
  /// Apply These Terms" appendix describes as the ordinary arrangement.
  static let notice = """
    ZenPom — a Pomodoro timer built around the distraction log.
    Copyright © 2026 Martin Gleason

    This program is free software: you can redistribute it and/or modify it \
    under the terms of the GNU General Public License as published by the Free \
    Software Foundation, either version 3 of the License, or (at your option) \
    any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT \
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or \
    FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for \
    more details: https://www.gnu.org/licenses/gpl-3.0.html
    """

  /// The App Store pledge, in one sentence the screen can carry.
  ///
  /// The full text is `LICENSE-EXCEPTION.md` in the repository. What matters to a
  /// reader of the app is that it exists and what kind of thing it is — a
  /// non-enforcement pledge by the copyright holder, not a second licence.
  static let appStoreException = """
    The copy of ZenPom on the App Store is this same software under this same \
    licence. The copyright holder has pledged never to enforce the one conflict \
    between the GPL and Apple's App Store terms — the same arrangement Signal, \
    Nextcloud and Telegram use.
    """

  /// Where the source is, so every sentence above is checkable rather than a claim.
  static let sourceURL = URL(string: "https://github.com/martin-gleason/ZenTomato")!
}
