import Foundation
import Testing

/// The citation walk's exclusion list, guarded from both sides.
///
/// Split out of `DeltaIntegrityTests` because that file is at its length limit and this is a
/// different concern: `DeltaIntegrityTests` asks whether the citations resolve, and this asks
/// whether the thing doing the asking is still looking at anything.
@Suite("DeltaCitationSurface")
struct DeltaCitationSurfaceTests {
  /// `theExclusionIsNarrow` — excluding the vendored baseline must not quietly stop checking
  /// anything else.
  ///
  /// `everyCitedDeltaIsDefined` fails **open**: a file that stops being walked reports nothing and
  /// the suite goes green. That is this project's own scar — fifteen checks passed over a parser
  /// returning the same title for every row. An exclusion list is exactly the shape of thing that
  /// widens one entry at a time until the assertion above walks nothing.
  @Test("theExclusionIsNarrow")
  func theExclusionIsNarrow() throws {
    let walked = try DeltaIntegrityTests.citingFiles().map(\.path)

    #expect(
      walked.contains(where: { $0.hasSuffix("docs/conventions.md") }) == false,
      "The vendored upstream baseline must not be read as a citation surface (D24).")

    #expect(
      walked.contains(where: { $0.hasSuffix("docs/conventions-local.md") }),
      "This project's own conventions file must still be checked; it cites D24.")

    #expect(
      walked.contains(where: { $0.hasSuffix("docs/plans/F2d.md") }),
      "The plans must still be checked.")
  }
}
