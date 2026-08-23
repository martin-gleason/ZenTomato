import UIKit

/// The single short thump that says a distraction was written down.
///
/// WHY THIS IS A FILE AND NOT ONE LINE INSIDE THE BUTTON
/// Everything the app draws is SwiftUI, which is the framework the whole design
/// system is expressed in; UIKit is the older one underneath it. Haptics are one
/// of the few things SwiftUI still cannot express with the precision this
/// feature needs — see below — so the dependency is admitted in a file whose
/// entire job is to admit it, rather than leaking into a view. **This is the
/// only file in the distraction feature, and the only screen-side file in the
/// feature, that knows UIKit exists.**
///
/// It is not the app's only `import UIKit`, and claiming otherwise would be a
/// comment promising an enforcement nobody wrote. The true statement is that
/// there are three, each doing one small platform-specific job that SwiftUI has
/// no equivalent for: turning a design-system colour into something paintable
/// (`Color+ColorRole.swift`), opening the Settings app
/// (`AlarmPermissionView.swift`), and this. None of them is a UIKit *screen*,
/// and the day one appears is the day this containment has actually been lost.
///
/// WHY NOT SwiftUI's OWN `.sensoryFeedback`
/// SwiftUI's version is driven by a *value changing* on screen. That is one
/// step removed from the thing this buzz is supposed to certify. The rule for
/// this whole feature is that the tap is the record, and the buzz is the
/// **receipt** for a row that is already committed to disk — not a promise that
/// one is about to be. So it is fired from exactly one place, on exactly one
/// condition: `TimerEngine.recordDistraction(_:)` returned `true`. If the write
/// is refused, nothing is felt. A person who logs a distraction without looking
/// at the screen — which is most of them, since looking at the screen is the
/// distraction — can trust the buzz completely, because there is no path in the
/// code where it fires for a row that does not exist.
///
/// WHY AN IMPACT AND NOT A SUCCESS CHIME
/// `.impact` is one short, firm thump. The notification-style patterns
/// (`.success`, `.warning`) are multi-part, take roughly half a second, and
/// carry a value judgement. A distraction is neither good nor bad; it is a fact
/// that has been written down. One impact says "written down" and then gets out
/// of the way, which is the correct length for an interruption inside an app
/// that exists to measure interruptions.
@MainActor
enum CaptureHaptic {
  // MARK: Internal

  /// A row was committed. Called once per successful tap and never otherwise.
  static func tapRecorded() {
    // Full intensity. The scale runs 0 to 1 and this is the one signal in the
    // app that has to be unmistakable through a pocket.
    generator.impactOccurred(intensity: 1)
    // Warmed again for the next tap. Two taps a few seconds apart is a normal
    // thing to do, and this is what makes the second one land as promptly as
    // the first.
    generator.prepare()
  }

  /// The capture buttons have appeared, so a tap is now possible.
  ///
  /// Called when the pair comes on screen at the start of a focus block. It
  /// starts no work of its own and returns immediately, so it is safe on the
  /// tap path's no-`Task` rule and safe in a view's `onAppear`.
  static func warmUp() {
    generator.prepare()
  }

  // MARK: Private

  /// Kept rather than built per tap, and asked to warm up before it is used.
  ///
  /// The Taptic Engine idles down when nothing is buzzing, and the first thump
  /// after an idle period pays the cost of waking it — felt as the buzz arriving
  /// slightly after the finger has already lifted. Taps in this app are minutes
  /// apart, so essentially every first tap of a block would pay it.
  ///
  /// **Keeping the generator alive is not by itself what avoids that**, and an
  /// earlier version of this comment claimed it was. `prepare()` is the call
  /// that warms the engine; a long-lived generator is simply the thing there is
  /// to call it on. It is called twice — when the buttons appear, and again
  /// after each tap — so the receipt lands while the finger is still down, which
  /// is when it means anything.
  private static let generator = UIImpactFeedbackGenerator(style: .medium)
}
