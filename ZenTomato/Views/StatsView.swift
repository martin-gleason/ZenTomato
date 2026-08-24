import SwiftData
import SwiftUI

/// The pomodoro history sheet: the chrome, and the one place the query is built.
///
/// The same split `TimerView` and `TimerScreen` already use, for the same
/// reason. This file knows a database exists; `StatsScreen` does not, which is
/// what lets every state of the screen be looked at in a preview with nothing
/// counting behind it.
///
/// **`StatsQuery` is built once, here, and asked from a `.task`.** Never from a
/// `body`: a query inside `body` runs on every redraw, and no amount of speed
/// saves it. `StatsScreenModel.load()` then answers *today* first and publishes
/// it before it looks at the chosen range, so the number this screen exists to
/// show is not waiting behind a fortnight of rows.
///
/// The chrome is `SettingsView`'s chrome exactly — a navigation stack, an inline
/// title, `Done` in the confirmation slot — so the two sheets read as siblings.
///
/// **The title is "Pomodoros", not "Stats".** The word *stats* is itself the
/// pressure this feature has to resist: it invites the chart, the trend and the
/// streak. *Pomodoros* names the unit, and the first number on the screen.
struct StatsView: View {
  // MARK: Internal

  var body: some View {
    NavigationStack {
      content
        .navigationTitle(StatsScreenModel.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(StatsScreenModel.doneLabel) { dismiss() }
              .accessibilityHint(Text("Closes your pomodoro history."))
          }
        }
        .task {
          guard model == nil else { return }
          let built = StatsScreenModel(
            query: StatsQuery(context: context),
            today: StatsDay.containing(.now, in: .current))
          built.load()
          model = built
        }
    }
  }

  // MARK: Private

  @Environment(\.modelContext) private var context

  @Environment(\.dismiss) private var dismiss

  /// Built in `.task` rather than in `init`, because the store arrives through
  /// the environment and the environment is not readable in an initialiser.
  /// The page it paints in the one frame before that is the page colour, not a
  /// spinner: there is nothing to wait for that is worth naming.
  @State private var model: StatsScreenModel?

  @ViewBuilder
  private var content: some View {
    if let model {
      StatsScreen(model: model)
    } else {
      Color(.surfacePrimary).ignoresSafeArea()
    }
  }
}
