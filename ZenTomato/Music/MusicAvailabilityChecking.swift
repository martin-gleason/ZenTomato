import Foundation

/// Everything this app needs to know about whether it may play music, and
/// nothing about which framework answers.
///
/// **WHY THIS IS A PROTOCOL AND NOT A HANDFUL OF DIRECT CALLS.** Two of the
/// three questions underneath it can only be answered by a real phone signed in
/// to a real account: the build machine has no music library, no Apple Music
/// subscription and no way to grant a permission. If the coordinator asked the
/// framework directly, then every test of "what happens when permission is
/// refused" would be untestable and the D19.2 promise — that every music
/// failure leaves a working timer — would be a claim rather than a proved fact.
/// Behind this protocol a test hands over any answer it likes, including the
/// ones that cannot be produced on demand anywhere.
///
/// It is also the same insurance the alarm protocol takes out: nothing above
/// this line names a music framework type, so the one file that does can be
/// replaced without touching the coordinator, the screens or a single test.
///
/// **NOTHING HERE CAN THROW INTO THE APP.** The underlying subscription read
/// suspends and can fail, and a failure has to become `couldNotBeChecked` —
/// a fact the screen states in one quiet line — rather than an error travelling
/// upwards towards a timer that has nothing to do with it. That obligation
/// belongs to the implementation and is written here so that any future
/// implementation inherits it rather than rediscovering it.
///
/// `@MainActor` for the same reason as everything else in this feature: one
/// thread, so a permission answer arriving late and a block boundary arriving
/// now cannot interleave. `AnyObject` because an implementation holds state —
/// the last answer it got — and a value type would copy it.
@MainActor
protocol MusicAvailabilityChecking: AnyObject {
  /// The last answer, free to read and never suspending.
  ///
  /// Read at start-up so the screen has something true to draw before any
  /// asking has happened. On a fresh install that is `notAsked`.
  var current: MusicAvailability { get }

  /// Asks again, without prompting anybody for anything.
  ///
  /// Safe to call at any time and as often as wanted: it reads a permission
  /// that has already been decided and a subscription state that already
  /// exists. It never puts a system prompt in front of the user — that is
  /// `requestAuthorization()`'s job alone, and keeping the two apart is what
  /// stops a prompt appearing at launch.
  func refresh() async -> MusicAvailability

  /// Asks the user for permission to use their music, then reports where that
  /// leaves things.
  ///
  /// **Called at the moment somebody first switches music on, and nowhere
  /// else.** Not at launch, not when the picker opens, not when a block starts.
  /// A permission prompt for a feature the person has not touched yet is the
  /// surest way to be refused, and this is the same rule the alarm permission
  /// already follows at the first tap on Start.
  ///
  /// Calling it when permission has already been settled does not ask twice —
  /// the system answers from what it already knows — so it is safe to route
  /// every switch-on through here.
  func requestAuthorization() async -> MusicAvailability

  /// A stream of new answers as the world changes underneath the app.
  ///
  /// The one that matters in practice is a subscription lapsing in the middle
  /// of a sprint. When that happens the music stops and the block carries on to
  /// its own end, which is D19.2 in its sharpest form: the most a lapsed
  /// subscription can do to this app is make it quiet.
  ///
  /// The caller owns the returned stream and stops it by cancelling the task it
  /// is being read in. Nothing here runs unattended.
  func changes() -> AsyncStream<MusicAvailability>
}
