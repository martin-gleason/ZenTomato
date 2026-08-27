import Foundation

/// The licence text the app itself can show.
///
/// **MIT REQUIRES THIS, AND IT IS THE ONLY THING MIT REQUIRES.**
///
/// > The above copyright notice and this permission notice shall be included in
/// > all copies or substantial portions of the Software.
///
/// A copy of the app is a copy of the Software. So the notice has to travel
/// *inside the binary* — a licence file sitting in the repository satisfies the
/// repository's licence, not the app's. Shipping ZenPom under MIT with no licence
/// text reachable in the app would put the app out of compliance with its own
/// terms.
///
/// **Held here rather than read from a bundled file** so that it cannot be
/// silently absent: a missing resource is a runtime surprise, and a missing
/// constant does not compile. `LicenceFenceTests` checks the words are really
/// here, and `C18`'s About screen is what puts them in front of somebody.
enum AppLicence {
  /// What governs this app, in full. Reproduced rather than summarised, because a
  /// summary of a licence is not the licence.
  static let mit = """
    Copyright © 2026 Martin Gleason

    Permission is hereby granted, free of charge, to any person obtaining a copy \
    of this software and associated documentation files (the "Software"), to deal \
    in the Software without restriction, including without limitation the rights \
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
    copies of the Software, and to permit persons to whom the Software is \
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in \
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING \
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER \
    DEALINGS IN THE SOFTWARE.
    """

  /// What governs the **source**, which is a different thing and must not be
  /// mistaken for the above.
  ///
  /// Two sentences, each naming what it covers, and no "or" between the licence
  /// names — the wording rule `scripts/check-licence-wording.sh` enforces across
  /// the prose. The app is held to the same rule as the README.
  static let sourceNotice = """
    ZenPom's source code is licensed GPL-3.0-or-later and is public. This app, as \
    a compiled binary, is licensed MIT. These cover two different things.
    """

  /// Where the source is, so the sentence above is checkable rather than a claim.
  static let sourceURL = URL(string: "https://github.com/martin-gleason/ZenTomato")!
}
