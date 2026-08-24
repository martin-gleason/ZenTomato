import Foundation

/// Writes the export to a real file and hands back its URL.
///
/// **This is the only I/O in the whole feature, and it lives here rather than in
/// `ZenTomato/Export/` on purpose.** That directory is a pure function of a
/// value — no clock, no calendar, no reader's region setting, no disk — and that
/// purity is what makes the committed golden file evidence rather than
/// decoration. One `FileManager` call inside it would end that, so the file
/// writing sits outside the fence, in the layer that already knows the phone
/// exists.
///
/// WHY A FILE AND NOT A STRING
/// `ShareLink` will happily share a `String`, and what arrives in Files when it
/// does is `Untitled.txt`. The document *is* this feature — F6 exists to produce
/// the page a fortnightly review is read from — so it leaves the app as
/// `ZenTomato-2026-08-08-to-2026-08-21.md`: sortable, self-describing, and still
/// meaningful sitting in a folder a month later.
///
/// WHY THE DIRECTORY IS SWEPT FIRST
/// Each share writes a new file, and a range picked five times in a sitting is
/// five documents. Nothing else in this app ever deletes them, so without the
/// sweep the temporary directory accumulates a fortnight per tap for the life of
/// the install. Only files this app wrote are removed, matched by the same name
/// shape `StatsMarkdown.filename(for:)` produces.
enum StatsExportFile {
  /// Writes the document and returns where it went.
  ///
  /// - Throws: whatever the filesystem says. A failed write is reported to the
  ///   reader as one plain sentence and the share control goes with it —
  ///   sharing a stale file would be worse than sharing none.
  static func write(document: String, filename: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
    sweep(directory)

    let url = directory.appending(path: filename)
    // UTF-8 with `\n` line endings and a trailing newline, exactly as
    // `StatsMarkdown` built it. `.atomic` so a share sheet can never be handed a
    // half-written page.
    try Data(document.utf8).write(to: url, options: .atomic)
    return url
  }

  // MARK: Private

  /// The name shape this app writes, and the only files it will ever delete.
  private static let prefix = "ZenTomato-"
  private static let suffix = ".md"

  /// Removes the pages left behind by earlier shares.
  ///
  /// Failures are ignored, deliberately and with an argument: a file that cannot
  /// be removed is a stale document nobody is going to open, and refusing to
  /// export because tidying up failed would turn a housekeeping problem into a
  /// lost feature. Nothing is read from these files, so a leftover cannot make
  /// anything wrong — only untidy.
  private static func sweep(_ directory: URL) {
    guard
      let contents = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil)
    else { return }

    for file in contents
    where file.lastPathComponent.hasPrefix(prefix) && file.lastPathComponent.hasSuffix(suffix) {
      try? FileManager.default.removeItem(at: file)
    }
  }
}
