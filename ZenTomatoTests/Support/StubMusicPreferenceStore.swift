import Foundation

@testable import ZenTomato

/// A stand-in for the two remembered music facts, holding them in memory.
///
/// The real one is a row in the app's database. The coordinator's job is
/// deciding when there should be sound, and giving it a database to do that
/// would mean every test of the decision needed a store opened, a schema
/// migrated and a row created — for two values. Behind the protocol they are
/// two values, which is all they ever were.
///
/// It also records every write, in order, because *when* something is
/// remembered is part of the requirement: a permission that comes back refused
/// must put the switch back to off and write that down, so the next launch does
/// not start with a switch sitting on while nothing can play.
@MainActor
final class StubMusicPreferenceStore: MusicPreferenceStoring {
  /// Whether music is switched on.
  private(set) var isEnabled: Bool

  /// The chosen playlist or song.
  private(set) var selection: MusicSelection?

  /// Every write, in order, as short readable text.
  private(set) var writes: [String] = []

  init(isEnabled: Bool = false, selection: MusicSelection? = nil) {
    self.isEnabled = isEnabled
    self.selection = selection
  }

  func setEnabled(_ isEnabled: Bool) {
    self.isEnabled = isEnabled
    writes.append("enabled: \(isEnabled)")
  }

  func setSelection(_ selection: MusicSelection?) {
    self.selection = selection
    writes.append("selection: \(selection?.identifier ?? "none")")
  }
}
