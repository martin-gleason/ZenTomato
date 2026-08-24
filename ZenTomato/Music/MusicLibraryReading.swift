import Foundation

/// Everything this app is allowed to ask of somebody's music library.
///
/// **THREE READS AND NO WRITES, AND THE FENCE IS THE TYPE.**
/// `SPEC.md`'s out-of-scope list names building a default playlist for focus
/// blocks by name, and `CLAUDE.md`'s standing rule is that this app has no
/// capture surface of any kind. Both of those are usually defended with a
/// comment asking people not to. This defends them with a shape: there is no way to say "make one",
/// "rename that", "put this in that", "reorder those" or "delete it" through this
/// protocol, because no such method exists. The concrete framework underneath
/// offers all of them — a playlist is a writable thing as far as Apple is
/// concerned — and none of that surface reaches the rest of the app.
///
/// An engineer who wants to build a playlist cannot do it without adding a method
/// here, and that edit is a diff the owner reads. That is the mechanism; this
/// paragraph is only the explanation.
///
/// **The user's own library, never the Apple Music catalogue.** `SPEC.md` says
/// *"an existing playlist or song from their library"*. A catalogue result is
/// something the person does not own and cannot be given, so offering one would
/// be offering a control that fails. The one implementation of this protocol
/// makes library requests and no catalogue request of any kind, and the scope
/// fence greps for that.
///
/// WHY IT DEALS IN `MusicSelection` RATHER THAN IN THE FRAMEWORK'S OWN TYPES
/// A `MusicSelection` is three plain strings. Nothing above this line names a
/// framework type, which is what lets the picker, the row and their tests run
/// with a stub and no music framework anywhere near them — and it is why exactly
/// three files in this repository import that framework.
///
/// MAIN-THREAD ONLY, like every other collaborator this app hands to a screen.
@MainActor
protocol MusicLibraryReading: AnyObject {
  /// Every playlist in the user's own library, in the order the library returns
  /// them.
  ///
  /// **No order of our own.** The library's order is the one the person already
  /// knows from the Music app, and re-sorting it here would be this app forming
  /// an opinion about somebody else's music — the same judgement the Todoist
  /// mirror refuses to make about their projects.
  func playlists() async throws -> [MusicSelection]

  /// Every song in the user's own library, in the same order the library returns
  /// them.
  func songs() async throws -> [MusicSelection]

  /// Whether a chosen item is still in the library, and what it is called now.
  ///
  /// - Returns: the item with its current title, or `nil` when it is no longer
  ///   in the library. `nil` is the **only** route to the "that one isn't in your
  ///   library any more" state, which is why this is a read rather than a piece
  ///   of arithmetic on a title snapshot.
  func resolve(_ selection: MusicSelection) async throws -> MusicSelection?
}
