import SwiftUI

/// A tomato, filled to a fraction. **The app's only tomato.**
///
/// `design_handoff_v1.5_upgrade` specifies it twice — once for the Dynamic Island and once for the
/// garden — and the two agree: a circle, a crown of triangular sepals from the top point, in a 24 × 26
/// box. They differ only in whether the body is outlined or solid and in the crown's shade. So this is
/// one type with a style rather than two drawings, which is what stops `F16`'s garden and `F2f`'s Island
/// from growing different fruit.
///
/// **IT LIVES IN THE DESIGN SYSTEM AND NOT IN THE WIDGET, DELIBERATELY.** `F16` is earlier in v1.5's
/// order than `F2f` and will draw dozens of these; the Island draws one at 26 points. Whichever ships
/// first would otherwise define the app's tomato by accident, and the garden is where a person actually
/// looks at one.
///
/// **The fill is a fraction, not a clock.** `D57`: the tomato fills **by finished pomodoro**, stepping
/// at each boundary, and the cup stays on breaks. It does not animate itself and must not try —
/// WidgetKit *"animates content-state transitions itself; you cannot drive keyframes, and elaborate
/// animations are dropped"*, so a step at a boundary is animated for free and a smooth rise is dropped
/// on the floor. `F2f-T1` established that the hard way: a system progress view rotated, scaled and
/// clipped to this shape drew nothing at all.
struct TomatoGlyph: View {
  /// How full, from 0 to 1. Clamped rather than trusted: a fraction above one would draw past the rim,
  /// and the caller computing it is doing division.
  let fill: Double

  /// Whether the body is drawn as an outline that fills, or as a solid fruit.
  ///
  /// The Island wants the first — an empty tomato that fills as the sprint is worked through. The
  /// garden wants the second, because a tomato there *is* a finished pomodoro and has nothing to fill.
  var style: Style = .filling

  enum Style {
    /// An outlined body with the flesh rising inside it. The Island's form.
    case filling
    /// A solid fruit. The garden's form, and the app icon's.
    case solid
  }

  var body: some View {
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height)
      let bodyTop = side * Self.crownHeightRatio
      let bodyRect = CGRect(x: 0, y: bodyTop, width: side, height: side - bodyTop)

      ZStack(alignment: .topLeading) {
        // The flesh, clipped to the body. For `.solid` the fraction is ignored and the fruit is whole.
        //
        // **A RECTANGLE CLIPPED TO A CIRCLE, WHICH IS THE HANDOFF'S OWN CONSTRUCTION** — *"rect clipped
        // to the circle, origin bottom."* What `F2f-T1` found unbuildable was driving it from a system
        // progress view; driven by a number this program already has, it is an ordinary shape.
        Rectangle()
          .fill(Color(.tomatoFlesh))
          .frame(
            width: bodyRect.width,
            height: bodyRect.height * (style == .solid ? 1 : clamped))
          .offset(y: bodyRect.maxY - bodyRect.height * (style == .solid ? 1 : clamped))
          .clipShape(Circle().path(in: bodyRect))

        if style == .filling {
          Circle()
            .path(in: bodyRect)
            .strokedPath(.init(lineWidth: side * Self.outlineRatio))
            .foregroundStyle(Color(.tomatoSkin))
        }

        // The crown, over the flesh — the handoff's own stacking order: "leaf crown on top drawn over
        // the fill."
        Crown()
          .fill(Color(.tomatoLeaf))
          .frame(width: side * Self.crownWidthRatio, height: bodyTop * Self.crownReach)
          .offset(x: side * (1 - Self.crownWidthRatio) / 2)
      }
      .frame(width: side, height: side)
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityHidden(true)
  }

  // MARK: Private

  private var clamped: Double {
    min(max(fill, 0), 1)
  }

  /// Three triangular sepals from the top point, as the handoff describes the crown.
  ///
  /// **`addLines` RATHER THAN THE PAIR OF CALLS THAT WOULD BE OBVIOUS HERE, AND THE REASON IS NOT
  /// STYLE.** `TodoistEndpointTests.thisFeatureAddsNoWriteToTodoist` greps every app source for the
  /// five verbs `CLAUDE.md` forbids against Todoist — *"the only write to Todoist is complete task"* —
  /// and one of them is also the name of `Path`'s subpath-start call. The first draft of this shape
  /// used it and turned the fence red.
  ///
  /// **The fence is right to be broad and was not narrowed.** A guard against calling a forbidden
  /// endpoint should not learn exceptions for whichever SwiftUI API happens to share a verb; that is
  /// how a fence stops fencing, one reasonable exception at a time. `addLines` begins its own subpath,
  /// draws the same triangle, and needs no exception — so the drawing changed and the rule did not.
  ///
  /// **The grep reads comments as well as code**, so this note is written around the word rather than
  /// quoting it. That is not a workaround: a fence that cannot be described in the file it guards is
  /// telling you the rule is absolute, and this one is.
  private struct Crown: Shape {
    func path(in rect: CGRect) -> Path {
      var path = Path()
      let step = rect.width / 3
      for index in 0..<3 {
        let left = rect.minX + step * CGFloat(index)
        path.addLines([
          CGPoint(x: left, y: rect.maxY),
          CGPoint(x: left + step / 2, y: rect.minY),
          CGPoint(x: left + step, y: rect.maxY)
        ])
        path.closeSubpath()
      }
      return path
    }
  }

  /// Proportions rather than points, so one drawing serves a 20-point Island glyph and a garden full of
  /// larger ones. The handoff's 24 × 26 box is this shape at its smallest.
  private static let crownHeightRatio = 0.22
  private static let crownWidthRatio = 0.5
  private static let crownReach = 1.25
  private static let outlineRatio = 0.06
}
