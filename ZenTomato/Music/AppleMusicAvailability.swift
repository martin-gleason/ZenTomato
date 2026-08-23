@preconcurrency import MusicKit
import Foundation

/// The only file in this app that asks Apple whether music may be played.
///
/// Two separate questions have to be answered yes before a note comes out, and
/// they fail in completely different ways:
///
///   * **Has the person given this app permission to use their music?** They
///     are asked once, at the moment they first switch music on, and the answer
///     is remembered by iOS from then on. It can also be *restricted*, which is
///     not a refusal — it means a device policy or Screen Time has taken the
///     decision out of their hands, and there is nowhere useful to send them.
///   * **Is there an Apple Music subscription on this phone?** Playing an item
///     from a library through an app's own player needs one. This question
///     suspends and can fail on its own, which is why availability is an
///     `async` read with several answers rather than a boolean.
///
/// **THE ONE FLAG THAT IS DELIBERATELY NOT READ.** Apple also reports whether
/// the person *could* take out a subscription, and offers a ready-made screen
/// for selling them one. Neither is used and neither ever will be here. A
/// commerce surface is not among the features this app was contracted to build,
/// and an app that answers "you can't use this" with "would you like to buy
/// something" is not a calm one.
///
/// **NOTHING IN HERE CAN THROW INTO THE APP.** Every failure below becomes
/// `MusicAvailability.couldNotBeChecked` — a fact the timer screen states in one
/// quiet grey line — rather than an error travelling upwards towards a timer
/// that has nothing to do with any of this. That is D19.2 at the point where it
/// is easiest to get wrong, because the temptation is to let the caller decide
/// and there is no caller who could.
///
/// See `AppleMusicPlayer` for why the import is written the way it is.
@MainActor
final class AppleMusicAvailability: MusicAvailabilityChecking {
  // MARK: Lifecycle

  init() {
    // What can be known without suspending, and nothing more. A refusal and a
    // restriction are already decided and are worth drawing in the very first
    // frame. Permission having been granted is *not* enough to say music is
    // ready, because the subscription has not been read yet — so that case
    // starts as "never asked", which draws no explanation at all and no claim
    // that is about to be corrected. `start()` on the coordinator asks properly
    // a moment later.
    current = switch MusicAuthorization.currentStatus {
    case .denied: .denied
    case .restricted: .restricted
    default: .notAsked
    }
  }

  // MARK: MusicAvailabilityChecking

  /// The last answer. Free to read and never suspends.
  private(set) var current: MusicAvailability

  /// Asks again, prompting nobody for anything.
  ///
  /// Reads a permission that has already been decided and a subscription state
  /// that already exists. It cannot put a system prompt on screen, which is
  /// what makes it safe to call at launch.
  func refresh() async -> MusicAvailability {
    let answer = await Self.availability(for: MusicAuthorization.currentStatus)
    current = answer
    return answer
  }

  /// Asks the person for permission to use their music, then reports where that
  /// leaves things.
  ///
  /// **This is the only line in the app that can put the music permission
  /// prompt on screen**, and it is reached only by switching music on. Not at
  /// launch, not when the picker opens, not when a block starts. Asking for a
  /// permission before somebody has shown any interest in the feature it is for
  /// is the surest way to be refused — the same rule the alarm permission
  /// already follows at the first tap on Start.
  ///
  /// Safe to call when permission has already been settled: iOS answers from
  /// what it already knows rather than asking twice.
  func requestAuthorization() async -> MusicAvailability {
    let status = await MusicAuthorization.request()
    let answer = await Self.availability(for: status)
    current = answer
    return answer
  }

  /// New answers as the world changes underneath the app.
  ///
  /// In practice this reports one thing: a subscription starting or ending. The
  /// case that matters is it ending in the middle of a sprint — the music
  /// stops, the block runs to its own end, and the timer is never told.
  ///
  /// The permission is read again alongside each subscription change rather
  /// than assumed, because a person can revoke it in the Settings app while
  /// this app is in the background and the first this app hears of it should
  /// not be a failure to play.
  func changes() -> AsyncStream<MusicAvailability> {
    AsyncStream { continuation in
      let listener = Task { @MainActor [weak self] in
        for await subscription in MusicSubscription.subscriptionUpdates {
          let answer = Self.availability(
            for: MusicAuthorization.currentStatus,
            subscription: subscription)
          self?.current = answer
          continuation.yield(answer)
        }
        continuation.finish()
      }

      continuation.onTermination = { _ in listener.cancel() }
    }
  }

  // MARK: Private

  /// Both questions, asked properly.
  private static func availability(for status: MusicAuthorization.Status) async -> MusicAvailability {
    guard status == .authorized else {
      return availability(for: status, subscription: nil)
    }

    do {
      let subscription = try await MusicSubscription.current
      return availability(for: status, subscription: subscription)
    } catch {
      // Reading the subscription failed. That is not the same as there being no
      // subscription, so it is not reported as one: this app says it does not
      // know, the row shows one quiet line, and the timer is untouched. The
      // error is turned into a fact rather than discarded.
      return .couldNotBeChecked
    }
  }

  /// Both answers, combined into the one value the rest of the app uses.
  ///
  /// - Parameters:
  ///   - status: what the person said about permission.
  ///   - subscription: what Apple said about the subscription, or `nil` when
  ///     that has not been established. `nil` only matters when permission has
  ///     been granted, because nothing else gets far enough to care.
  private static func availability(
    for status: MusicAuthorization.Status,
    subscription: MusicSubscription?
  ) -> MusicAvailability {
    switch status {
    case .notDetermined:
      return .notAsked

    case .denied:
      return .denied

    case .restricted:
      return .restricted

    case .authorized:
      guard let subscription else { return .couldNotBeChecked }
      // The honest flag is whether this phone can play catalogue content, which
      // is what a library item is once it leaves the person's own device. There
      // is no flag called "is subscribed", and the wording of the line the row
      // shows follows from this one rather than from the word "subscription".
      return subscription.canPlayCatalogContent ? .ready : .noSubscription

    @unknown default:
      // An answer that did not exist when this was written. Not knowing is
      // reported as not knowing, which leaves a silent working timer.
      return .couldNotBeChecked
    }
  }
}
