import SwiftUI
import WidgetKit

/// `F2f-T1` — **THE SPIKE. THIS FILE IS NOT THE FEATURE AND MUST NOT SURVIVE `T3`.**
///
/// It exists to answer one question that cannot be answered by reading documentation or by arguing:
///
/// > **Can a tomato-shaped fill rise as a block elapses, in a Live Activity, without the app pushing a
/// > single update?**
///
/// `D55` ratified the *appearance* the owner wants — the handoff's *"red fill rising from the base as the
/// block elapses"* — and left the mechanism explicitly unsettled, because `conventions.md` says a
/// decision about what another system can do is not ratifiable until something has run. **The agent's
/// reasoning about this has already been wrong once inside a day**: first that no self-driving mechanism
/// exists at all (false — `ProgressView(timerInterval:)` is one), then that none exists for a custom
/// shape, which is better argued and was still unrun until this file.
///
/// **THREE CANDIDATES, SIDE BY SIDE, WHICH IS THE HANDOFF'S OWN INSTRUCTION** —
/// `recreation-notes.md:41`: *"Island tomato: build ALL THREE metaphors side by side (ripen fill-up, ensō
/// ring draw, drain down)."* They are drawn together so the owner compares them in one glance on real
/// hardware rather than reading three descriptions.
///
/// | | Candidate | Mechanism | Expected |
/// |---|---|---|---|
/// | **A** | Ripen fill-up | system linear bar, turned a quarter, clipped to the body | **unknown — the question** |
/// | **B** | Ensō ring | the system's circular progress view, ringing a solid tomato | to move; the system draws it |
/// | **C** | The handoff, literally | a fraction computed here and a rect clipped to `scaleY` | **to sit still** |
///
/// **C IS `F2f-M4`, SHOWN RATHER THAN ARGUED.** It is the obvious implementation and the plan predicts it
/// fails — not with a red assertion but by not moving, which no test in this project can see. Drawing it
/// beside two that might move is the only way to make that visible, and it is why this spike's output is
/// an observation with a build number rather than a green tick.
///
/// **The colours here are placeholders and are wrong on purpose.** The handoff's `#E06A50`, `#948F84` and
/// `#8AA163` cannot appear in this target — `palette_outside_token_layer` forbids naming a palette step
/// in `ZenTomatoActivity` — and the roles they need belong to `F12`'s theme tables, which do not exist
/// yet. `F2f-T2` adds the roles properly. **`danger` is used for the flesh because it is the only red
/// role in the table, and shipping a "danger" red on a running timer would be a defect**; that is one of
/// the reasons this file cannot survive.
struct TomatoSpike: View {
  /// The block's span, when there is one. `nil` for a frozen or ended block, which draws nothing that
  /// claims to be moving.
  let interval: ClosedRange<Date>?

  /// What candidate **C** believes the fraction to be, evaluated once, when this view is rendered.
  let staticFraction: Double

  var body: some View {
    HStack(spacing: Spacing.sm) {
      labelled("A") { ripenFillUp }
      labelled("B") { ensoRing }
      labelled("C") { handoffLiteral }
    }
  }

  // MARK: The candidates

  /// **A — the candidate that would give the owner exactly what the handoff describes.**
  ///
  /// Nothing here computes a fraction. The system's own linear progress view already knows how to move
  /// between two dates; it is turned on its side so its bar runs bottom-to-top, stretched thick enough to
  /// cover the body, and clipped to a circle. If iOS keeps driving it through a rotation and a clip, the
  /// red rises and the extension never did any arithmetic.
  private var ripenFillUp: some View {
    ZStack {
      if let interval {
        ProgressView(timerInterval: interval, countsDown: false)
          .progressViewStyle(.linear)
          .tint(Color(.danger))
          .labelsHidden()
          // Sized along what will become the vertical axis, then turned. The scale is what makes a
          // four-point bar tall enough to be a fill rather than a line.
          .frame(width: Self.size)
          .scaleEffect(x: 1, y: Self.barStretch, anchor: .bottom)
          .rotationEffect(.degrees(-90))
          .frame(width: Self.size, height: Self.size)
      }
      shell
    }
    .frame(width: Self.size, height: Self.size)
  }

  /// **B — the fallback that is almost certainly going to move**, because the system draws the whole
  /// thing and nothing is clipped. A ring around a solid tomato rather than a fill inside an outline.
  private var ensoRing: some View {
    ZStack {
      Circle().fill(Color(.danger)).frame(width: Self.size * 0.62, height: Self.size * 0.62)
      if let interval {
        ProgressView(timerInterval: interval, countsDown: false)
          .progressViewStyle(.circular)
          .tint(Color(.action))
          .labelsHidden()
      }
    }
    .frame(width: Self.size, height: Self.size)
  }

  /// **C — the handoff's literal construction, and the one this spike expects to fail.**
  ///
  /// *"rect clipped to the circle, scaleY = progress, origin bottom."* The fraction is a number this
  /// program computed at render time, so it is correct at that instant and frozen afterwards. If it sits
  /// still on the phone while **A** rises, that is `F2f-M4` demonstrated.
  private var handoffLiteral: some View {
    ZStack(alignment: .bottom) {
      Rectangle()
        .fill(Color(.danger))
        .frame(width: Self.size, height: Self.size * staticFraction)
        .clipShape(Circle().path(in: CGRect(x: 0, y: 0, width: Self.size, height: Self.size)))
      shell
    }
    .frame(width: Self.size, height: Self.size)
    .clipShape(Circle())
  }

  // MARK: Shared parts

  /// The outline and the sepal crown, drawn over whatever is filling behind them — which is the handoff's
  /// own stacking order: *"leaf crown on top drawn over the fill."*
  ///
  /// Named `shell` and not `body`, because `body` is `View`'s own requirement and a second one would be
  /// the kind of shadowing that compiles in some contexts and not others.
  private var shell: some View {
    ZStack {
      Circle().strokeBorder(Color(.borderStrong), lineWidth: Self.outline)
      Crown().fill(Color(.action)).frame(width: Self.size * 0.55, height: Self.size * 0.3)
        .offset(y: -Self.size * 0.42)
    }
  }

  private func labelled(_ letter: String, _ glyph: () -> some View) -> some View {
    VStack(spacing: 2) {
      glyph()
      Text(letter).font(Typography.kicker).foregroundStyle(Color(.textSubtle))
    }
  }

  /// Three triangular sepals from the top point, per the handoff's description of the crown.
  private struct Crown: Shape {
    func path(in rect: CGRect) -> Path {
      var path = Path()
      let step = rect.width / 3
      for index in 0..<3 {
        let left = rect.minX + step * CGFloat(index)
        path.move(to: CGPoint(x: left, y: rect.maxY))
        path.addLine(to: CGPoint(x: left + step / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: left + step, y: rect.maxY))
        path.closeSubpath()
      }
      return path
    }
  }

  private static let size: CGFloat = 26
  private static let outline: CGFloat = 1.2
  /// Enough to turn the system bar into something the height of the body once rotated.
  private static let barStretch: CGFloat = 8
}
