import Foundation
import Testing

@testable import ZenTomato

/// The stop control (D20), split out because the main suite reached the
/// linter's body limit. That limit is worth keeping on a test file too: a suite
/// that grows without anybody noticing is one nobody reads.
@MainActor
struct MusicRowStopTests {
  /// Silence is asked for on a block that is playing, and it is offered only
  /// then — a stop button on a silent block is a control that does nothing.
  @Test("stopIsOfferedOnlyWhenThereIsSound")
  func stopIsOfferedOnlyWhenThereIsSound() {
    for state in [MusicRowModel.Playback.silent, .starting, .didNotStart] {
      let row = Self.row(isRunning: true, kind: .work, playback: state)
      #expect(row.canStop == false)
      #expect(row.canSkip == false)
    }
  }

  private static func row(
    isRunning: Bool,
    kind: BlockKind,
    playback: MusicRowModel.Playback = .silent
  ) -> MusicRowModel {
    MusicRowModel.forTimer(
      isRunning: isRunning,
      kind: kind,
      isEnabled: true,
      availability: .ready,
      selection: MusicSelection(kind: .playlist, identifier: "p.1", title: "Deep Focus"),
      playback: playback)
  }
}
