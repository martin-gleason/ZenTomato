import SwiftData
import SwiftUI

/// The application itself: the first thing that runs, and the only place the
/// on-device database is opened.
///
/// **What happens at launch, in order.**
/// 1. `init()` asks `AppModelContainer` to open the store and make sure the
///    settings row exists. That work either succeeds or it does not, and the
///    answer is kept as a `Result` — a value that holds *either* the opened store
///    *or* the error that stopped it.
/// 2. `body` looks at that answer and shows one of two screens: the timer, or a
///    plain-language explanation of what went wrong.
///
/// **Why there is no crash-on-failure here.** The obvious shortcut would be to
/// insist the store opens and let the app die if it does not. That would mean a
/// user whose device is out of disk space, or whose database file has been
/// damaged, sees the app bounce off the home screen with no explanation and no
/// clue what to do. `StoreUnavailableView` exists so that never happens, and it
/// is the reason this codebase contains no forced-success operators anywhere.
///
/// **Why the store is opened here and not inside a screen.** Opening a database
/// is expensive and must happen exactly once. SwiftUI rebuilds a screen's
/// contents many times a second; opening the store inside one would open it many
/// times. Doing it in `init()` and handing the result down is the supported
/// pattern.
@main
struct ZenTomatoApp: App {
  // MARK: Lifecycle

  init() {
    bootstrapResult = AppModelContainer.bootstrap()
  }

  // MARK: Internal

  var body: some Scene {
    WindowGroup {
      rootView
        // The app's single accent colour, set once at the root so that every
        // standard iOS control below it inherits the brand green rather than
        // the system's default blue. Setting it here rather than in an asset
        // file keeps one source of truth for the accent: `ColorRole.action`.
        .tint(Color(.action))
    }
  }

  // MARK: Private

  /// Either the opened database, or the error that prevented opening it.
  ///
  /// Resolved once at launch and never changed afterwards, which is why it is a
  /// constant rather than a piece of observed state.
  private let bootstrapResult: Result<ModelContainer, any Error>

  /// The timer if the store opened, the explanation screen if it did not.
  @ViewBuilder
  private var rootView: some View {
    switch bootstrapResult {
    case .success(let container):
      TimerView()
        .modelContainer(container)

    case .failure(let error):
      StoreUnavailableView(technicalDetail: error.localizedDescription)
    }
  }
}
