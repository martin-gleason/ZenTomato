import Foundation

/// Which of the three kinds of block the timer is running.
///
/// WHAT A READER WHO DOES NOT WRITE SWIFT NEEDS TO KNOW
/// An `enum` is a closed list of possibilities. There are exactly three kinds
/// of block in the Pomodoro method and there will never be a fourth, so the
/// compiler is told that once, here, and every piece of code that handles a
/// block is then obliged to handle all three. Adding a case would break the
/// build everywhere it is not handled — which is the desired behaviour, not a
/// nuisance.
///
/// WHY THE RAW VALUE IS A STRING RATHER THAN A NUMBER
/// These values are written into the database. A stored `0` would mean
/// nothing to anyone reading the file, and reordering the cases would silently
/// change what every historical row meant. `"work"` says what it is and cannot
/// be broken by reordering.
///
/// WHY `displayName` LIVES HERE AND NOT ON A SCREEN
/// Two different processes draw this name: the app's timer screen and the Live
/// Activity on the Lock Screen, which is a separate program. If each spelled
/// the name itself they could disagree, and the disagreement would only ever
/// be visible on a locked phone — the hardest possible place to notice it.
enum BlockKind: String, Codable, Sendable, CaseIterable {
  /// A focus block. The only kind that counts towards a sprint.
  case work

  /// The short rest that follows most focus blocks.
  case shortBreak

  /// The long rest that ends a sprint.
  case longBreak

  /// The name a person reads, on the timer screen and on the Lock Screen.
  var displayName: String {
    switch self {
    case .work: "Focus"
    case .shortBreak: "Short break"
    case .longBreak: "Long break"
    }
  }
}
