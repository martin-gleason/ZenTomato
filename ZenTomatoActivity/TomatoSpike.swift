import SwiftUI
import WidgetKit

/// `F2f-T1` — **THE SPIKE, SECOND ATTEMPT. THIS FILE MUST NOT SURVIVE `T3`.**
///
/// **THE FIRST ATTEMPT ASKED THREE QUESTIONS AT ONCE AND ANSWERED NONE OF THEM.** It drew three
/// candidate tomatoes side by side — a rotated system bar clipped to a circle, a circular progress
/// ring, and a fraction computed here — each built from several composed effects, inside WidgetKit,
/// which is the most restrictive rendering environment on this platform. The owner's report was
/// *"it didn't render completely. all that was done was the green tops for the first selection."*
///
/// **A crown drew and a circle did not, and that result is uninterpretable** — which is the lesson.
/// When the drawing and the mechanism are both unknown, a failure tells you nothing about either. The
/// question *"does a self-driving fill work?"* cannot be answered by a picture that also depends on
/// whether an outline happens to be visible against black.
///
/// So this version asks **one question per probe, with nothing composed**:
///
/// | Probe | What it is | What it answers |
/// |---|---|---|
/// | **1** | a bare `ProgressView(timerInterval:)`, linear | does a self-driving bar render here **at all**? |
/// | **2** | the same, circular | does the ring form render — which is the fallback design? |
/// | **3** | the tomato shape, static, in a proven-visible colour | does the **shape** draw, independent of any fill? |
///
/// **Probe 3 exists because of what the first attempt got wrong.** The crown appeared and the circle
/// did not, and the likeliest reason is not WidgetKit at all: `islandInk()` forces the dark half of
/// every role because the Island is always black, and `borderStrong` in dark is a dark grey — on a
/// black capsule, invisible. The crown used `action`, the app's sage, and showed. So probe 3 draws the
/// whole shape in `action`: if it appears, the geometry was always fine and the first attempt's circle
/// was painted black on black.
///
/// **One glance late in a block answers all three**, with no expanding and no comparing two
/// screenshots: a self-driving view is visibly advanced near the end of a block, and a thing that does
/// not render is absent rather than subtle.
struct TomatoSpike: View {
  /// The block's span, or `nil` when there is nothing honest to draw.
  let interval: ClosedRange<Date>?

  var body: some View {
    HStack(spacing: Spacing.sm) {
      labelled("1") { linearProbe }
      labelled("2") { circularProbe }
      labelled("3") { shapeProbe }
    }
  }

  /// **Probe 1 — is a self-driving linear progress view drawn here at all?**
  ///
  /// Deliberately bare: no tint, no rotation, no scale, no clip. Every one of those was in the first
  /// attempt, and any one of them could have been the thing that failed.
  @ViewBuilder
  private var linearProbe: some View {
    if let interval {
      ProgressView(timerInterval: interval, countsDown: false)
        .labelsHidden()
        .frame(width: Self.size * 2)
    }
  }

  /// **Probe 2 — the ring**, which is the fallback design if a shaped fill proves impossible: a solid
  /// tomato with a self-driving ring around it.
  @ViewBuilder
  private var circularProbe: some View {
    if let interval {
      ProgressView(timerInterval: interval, countsDown: false)
        .progressViewStyle(.circular)
        .labelsHidden()
        .frame(width: Self.size, height: Self.size)
    }
  }

  /// **Probe 3 — does the tomato's geometry draw?** Static, no fill, in `action`, which the first
  /// attempt proved is visible on the Island's black.
  private var shapeProbe: some View {
    ZStack {
      Circle().strokeBorder(Color(.action), lineWidth: Self.outline)
      Crown().fill(Color(.action))
        .frame(width: Self.size * 0.55, height: Self.size * 0.3)
        .offset(y: -Self.size * 0.42)
    }
    .frame(width: Self.size, height: Self.size)
  }

  private func labelled(_ number: String, _ probe: () -> some View) -> some View {
    VStack(spacing: 2) {
      probe()
      Text(number).font(Typography.kicker).foregroundStyle(Color(.textPrimary))
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
  private static let outline: CGFloat = 1.5
}
