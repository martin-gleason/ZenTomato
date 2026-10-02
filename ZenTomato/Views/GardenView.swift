import SwiftUI

/// The garden: finished work, drawn as tomatoes that only ever accumulate (`F16-T3`, `D48`).
///
/// **What this screen is, for a reader who does not write Swift.** A sheet with one picture on it.
/// It asks for one number — finished poms, ever — turns it into rows with `Garden`, and draws a
/// tomato for every item. It shows no number (`Q8`, ruled 2026-10-02: the picture carries it), no
/// dates, and nothing about what comes next. It accepts one gesture: leaving.
///
/// **It cannot reach the database, on purpose.** It is handed a way to ask for the count, and the
/// timer screen's wiring hands it `StatsQuery`'s lifetime count — the same function the Pomodoros
/// sheet counts with. `GardenFenceTests` reads this file and fails if a store, a date or a calendar
/// appears in it.
///
/// **Built to Apple's guidance, reviewed 2026-10-02** (`docs/plans/F16.md`):
/// - **One `Canvas`.** The tomato is drawn once per size as a Canvas symbol and stamped per item —
///   not one view per tomato, which at a year of work would be a hundred views redrawn together.
/// - **One spoken value.** A Canvas tells VoiceOver nothing about the shapes in it, and the rows are
///   banded, so the number of tomatoes is not the count. VoiceOver hears the real number instead.
/// - **No animation**, so there is no motion to reduce.
/// - **The tomato's size follows the reader's text size**, through `@ScaledMetric`.
///
/// **The theme reaches it** the way it reaches every sheet since `F12`: the tomato's three colours are
/// theme roles, and `ThemeReachesSheetsTests` keeps that true inside a presented sheet.
struct GardenView: View {
  // MARK: Internal

  /// Asked once per open, from `.task` — never from `body`, which runs on every redraw. `nil` means
  /// the database would not answer, which is not the same as nothing having grown.
  ///
  /// **The only thing this screen is handed** — `GardenFenceTests` counts its inputs. A second one, a
  /// date or a "days since" handed in beside the count, is how a rule about time would reach the
  /// picture without the garden's own files ever naming one.
  let countFinishedPoms: @MainActor () -> Int?

  var body: some View {
    NavigationStack {
      content
        .navigationTitle(Text("Garden"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
              .accessibilityHint(Text("Closes the garden."))
          }
        }
        .background(Color(.surfacePrimary).ignoresSafeArea())
    }
    .task {
      guard load == .waiting else { return }
      load = Load(countFinishedPoms())
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  /// `.waiting` for the one frame before the count arrives. That frame paints the page colour: roughly
  /// fifty milliseconds at a year of work (`Q5`) is nothing worth a spinner.
  @State private var load = Load.waiting

  /// The first row's tomato, in points, grown with the reader's text size.
  @ScaledMetric(relativeTo: .body) private var tomatoSide: CGFloat = 22

  @ViewBuilder private var content: some View {
    switch load {
    case .waiting:
      Color.clear
    case .unreadable:
      // The counting screen's own words: a claim about the app, never about the reader's work.
      ContentUnavailableView {
        Label(StatsScreenModel.unreadableHeading, systemImage: "exclamationmark.triangle")
      } description: {
        Text("Nothing is missing — the garden just couldn't reach your history. Close it and open it again.")
      }
      .foregroundStyle(Color(.textMuted))
    case .counted(let finishedPoms):
      let garden = Garden(finishedPoms: finishedPoms)
      if garden.itemCount == 0 {
        ContentUnavailableView {
          Label("Nothing has grown here yet", systemImage: "leaf")
        } description: {
          Text("Finish a pomodoro and a tomato appears. Nothing here is ever taken away.")
        }
        .foregroundStyle(Color(.textMuted))
      } else {
        GeometryReader { proxy in
          ScrollView {
            // Clamped: the first layout pass can offer no width at all, and a negative frame is an
            // error SwiftUI logs on every open (found at review).
            GardenBed(garden: garden, width: max(proxy.size.width - 2 * Spacing.md, 0), firstSide: tomatoSide)
              .padding(Spacing.md)
              .accessibilityElement()
              .accessibilityLabel(Text("Garden"))
              .accessibilityValue(Text(Self.spoken(finishedPoms)))
          }
        }
      }
    }
  }

  /// What the screen has to draw: nothing yet, a count, or the honest failure.
  enum Load: Equatable {
    case waiting
    case counted(Int)
    case unreadable

    init(_ count: Int?) {
      self = count.map(Load.counted) ?? .unreadable
    }
  }

  /// What VoiceOver says for the garden — the real count, not the number of tomatoes drawn.
  static func spoken(_ finishedPoms: Int) -> String {
    finishedPoms == 1 ? "1 finished pomodoro" : "\(finishedPoms) finished pomodoros"
  }
}

/// The picture: every row of the garden, wrapped to the width it is given.
///
/// The rows whose tomatoes stand for the most poms are drawn largest and first, at the back of the
/// bed; single poms are at the front. Nothing is drawn for space a row has not filled.
private struct GardenBed: View {
  let garden: Garden
  let width: CGFloat
  let firstSide: CGFloat

  var body: some View {
    let frames = Self.frames(for: garden, width: width, firstSide: firstSide)
    Canvas { context, _ in
      for item in frames {
        if let tomato = context.resolveSymbol(id: item.row) {
          // Placed by its centre, explicitly. The first build used the rectangle form of this call
          // and the last line of tomatoes came out cut in half — caught by looking at a render, which
          // no test here would have done.
          context.draw(tomato, at: CGPoint(x: item.rect.midX, y: item.rect.midY), anchor: .center)
        }
      }
    } symbols: {
      ForEach(garden.rows.indices, id: \.self) { row in
        TomatoGlyph(fill: 1, style: .solid)
          .frame(width: Self.side(row: row, first: firstSide), height: Self.side(row: row, first: firstSide))
          .tag(row)
      }
    }
    // One gap of room below the last line. A tomato's body reaches the bottom of its box, and a
    // Canvas stops drawing at its own edge, so without this the front line lost its lower edge —
    // found by rendering the screen and looking, at `F16-T3`.
    .frame(width: width, height: (frames.map(\.rect.maxY).max() ?? 0) + Self.gap)
  }

  /// Each row's tomato is a quarter larger than the one before it, so a row that stands for more
  /// poms reads as more without a word on screen.
  static func side(row: Int, first: CGFloat) -> CGFloat {
    first * (1 + 0.25 * CGFloat(row))
  }

  /// Where every tomato goes, back row first.
  static func frames(for garden: Garden, width: CGFloat, firstSide: CGFloat) -> [(row: Int, rect: CGRect)] {
    var placed: [(row: Int, rect: CGRect)] = []
    var y: CGFloat = 0
    for row in garden.rows.indices.reversed() where garden.rows[row] > 0 {
      let side = side(row: row, first: firstSide)
      let step = side + gap
      let perLine = max(Int((width + gap) / step), 1)
      for index in 0..<garden.rows[row] {
        let x = CGFloat(index % perLine) * step
        let lineY = y + CGFloat(index / perLine) * step
        placed.append((row, CGRect(x: x, y: lineY, width: side, height: side)))
      }
      let lines = (garden.rows[row] + perLine - 1) / perLine
      y += CGFloat(lines) * step + gap
    }
    return placed
  }

  private static let gap: CGFloat = 6
}

#Preview("A year of work, Ripen, light") {
  GardenView(countFinishedPoms: { 1_044 })
    .environment(\.theme, .ripen)
    .preferredColorScheme(.light)
}

#Preview("Forty, Plum, dark") {
  GardenView(countFinishedPoms: { 40 })
    .environment(\.theme, .plum)
    .preferredColorScheme(.dark)
}

#Preview("Nothing yet") {
  GardenView(countFinishedPoms: { 0 })
}

#Preview("Could not read") {
  GardenView(countFinishedPoms: { nil })
}

#Preview("Largest text") {
  GardenView(countFinishedPoms: { 40 })
    .dynamicTypeSize(.accessibility5)
}
