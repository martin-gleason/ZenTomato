import Testing

@testable import ZenTomato

/// The specification for `DistractionTally.summary(of:)`, written as tests.
///
/// Each one is deliberately separate rather than a single loop, so that when one
/// fails Xcode names the exact case that is wrong instead of just "it failed".
struct DistractionTallyTests {
  @Test("nothing at all")
  func noDistractions() {
    #expect(DistractionTally.summary(of: []) == "No distractions")
  }

  @Test("one internal")
  func oneInternal() {
    #expect(DistractionTally.summary(of: [.internalPull]) == "1 internal")
  }

  @Test("two internal")
  func twoInternal() {
    #expect(DistractionTally.summary(of: [.internalPull, .internalPull]) == "2 internal")
  }

  @Test("one external")
  func oneExternal() {
    #expect(DistractionTally.summary(of: [.externalInterruption]) == "1 external")
  }

  @Test("both kinds")
  func bothKinds() {
    let taps: [DistractionKind] = [.internalPull, .externalInterruption, .internalPull]
    #expect(DistractionTally.summary(of: taps) == "2 internal · 1 external")
  }

  /// Internal leads even when the external tap happened first. The summary
  /// describes the block, not the order you noticed things in.
  @Test("order of taps does not change the order of the summary")
  func orderIsAlwaysInternalFirst() {
    let taps: [DistractionKind] = [.externalInterruption, .internalPull]
    #expect(DistractionTally.summary(of: taps) == "1 internal · 1 external")
  }
}
