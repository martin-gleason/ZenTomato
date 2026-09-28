import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The exported page, offered **as text and as a file**, so the destination picks.
///
/// **`D51`, ratified by the owner 2026-09-27 — *"text and file."*** Found on the device: the export
/// arrived in Bear as an *attachment* rather than as the note's body, because a file was the only
/// thing offered.
///
/// **THE FILE WAS A DECISION AND IT IS NOT BEING REVERSED.** `StatsExportFile` argues it in as many
/// words: *"`ShareLink` will happily share a `String`, and what arrives in Files when it does is
/// `Untitled.txt`. The document **is** this feature."* Replacing the file with a string would trade one
/// complaint for the one that comment already anticipated and rejected — a fortnight of review notes
/// sitting in a folder with no name on it. So both are offered and neither is lost:
///
/// | Destination | What it takes |
/// |---|---|
/// | Files, iCloud Drive | the named `ZenPom-2026-08-08-to-2026-08-21.md` |
/// | Bear, Notes, Drafts, Obsidian | the Markdown as the note's **body** |
/// | Mail, Messages | whichever the receiving app asks for |
///
/// **THE ORDER OF THE REPRESENTATIONS IS THE WHOLE IMPLEMENTATION, AND IT IS EASY TO GET BACKWARDS.**
/// `Transferable` offers them in declaration order and a receiver takes the first it understands. The
/// file is declared **first** because the apps that can only take a file — Files, iCloud Drive — would
/// otherwise be handed text and write `Untitled.txt`, which is the exact regression the existing
/// comment warns about. A notes app reaches past the file to the text because it prefers plain text;
/// Files does not, because it cannot. `F6-M2` is the mutation that reverses them.
///
/// **No provider, and that is why this is v1.5.** Nothing here names Bear or any other app. Putting a
/// note *into* a named app, with its tag and folder, is `D53` and it is v2.0.
struct StatsExport: Transferable {
  /// The Markdown page itself.
  let document: String

  /// Where the file form of it was written. Produced by `StatsExportFile`, which owns the naming and
  /// the sweep.
  let fileURL: URL

  /// What the share sheet shows above the choices.
  let title: String

  /// Markdown's content type, by identifier rather than by `UTType.markdown`.
  ///
  /// **`UTType.markdown` is iOS 27 and this app's floor is 26.0** (`D1`), so naming it directly fails
  /// to compile — caught by the Release build rather than by a review. `net.daringfireball.markdown` is
  /// the identifier iOS itself uses for `.md`, it conforms to `public.plain-text`, and every app that
  /// takes plain text therefore still accepts it.
  ///
  /// The fallback is `.plainText` rather than a force unwrap: a system that does not know the
  /// identifier should hand over a readable page, not crash the share sheet. `swiftlint`'s
  /// `force_unwrapping` rule would refuse the alternative anyway, and it is right to.
  private static let markdown = UTType("net.daringfireball.markdown") ?? .plainText

  static var transferRepresentation: some TransferRepresentation {
    // FIRST, so an app that can only accept a file gets the named one. See the class note.
    FileRepresentation(exportedContentType: Self.markdown) { export in
      SentTransferredFile(export.fileURL)
    }
    // SECOND, so a notes app takes the page as a body. Markdown rather than bare plain text: it
    // conforms to plain text, so an app that wants text still gets it, and one that understands
    // Markdown is told what it is holding.
    DataRepresentation(exportedContentType: Self.markdown) { export in
      Data(export.document.utf8)
    }
    .suggestedFileName { $0.fileURL.lastPathComponent }
  }
}
