import Foundation
import SwiftData

/// Keeps a copy of the library so the picker opens instantly.
///
/// **Show what we have, then go and check.** Opening the sheet draws the
/// remembered list immediately and refreshes behind it. A person with a large
/// library sees their playlists at once instead of a spinner, and the list
/// corrects itself a moment later if anything changed.
///
/// That is the same shape the Todoist cache uses, deliberately: one pattern for
/// "a local mirror of somebody else's data" rather than two that behave
/// differently for no reason a reader could name.
@MainActor
final class MusicLibraryCache {
  // MARK: Lifecycle

  init(context: ModelContext, library: any MusicLibraryReading) {
    self.context = context
    self.library = library
  }

  // MARK: Internal

  /// What was remembered last time, oldest-first within each kind.
  ///
  /// Returns an empty list when nothing has been cached, which the caller must
  /// treat as *"not looked yet"* rather than *"the library is empty"*. The two
  /// look identical here and mean opposite things — the same three-answer
  /// caution the session plan takes with Todoist.
  func remembered() -> [MusicSelection] {
    let descriptor = FetchDescriptor<CachedMusicItem>(
      sortBy: [SortDescriptor(\.title)])
    return ((try? context.fetch(descriptor)) ?? []).map(\.selection)
  }

  /// Whether anything has ever been cached.
  var hasEverRead: Bool {
    ((try? context.fetchCount(FetchDescriptor<CachedMusicItem>())) ?? 0) > 0
  }

  /// Reads the library and replaces the mirror.
  ///
  /// **A full replace, never a merge.** A merge has to decide what to do about
  /// an item present on one side and not the other, and every answer to that is
  /// the cache having an opinion about which side is right. Deleting everything
  /// and writing what the library just said cannot drift.
  @discardableResult
  func refresh() async throws -> [MusicSelection] {
    let playlists = try await library.playlists()
    let songs = try await library.songs()
    let now = Date()

    try context.delete(model: CachedMusicItem.self)
    for item in playlists + songs {
      context.insert(CachedMusicItem(
        kind: item.kind, identifier: item.identifier, title: item.title, syncedAt: now))
    }
    try context.save()
    return playlists + songs
  }

  /// Forgets everything. Used when music is switched off for good, so that a
  /// stale copy of somebody's library does not sit on disk unread.
  func clear() {
    try? context.delete(model: CachedMusicItem.self)
    try? context.save()
  }

  // MARK: Private

  private let context: ModelContext
  private let library: any MusicLibraryReading
}
