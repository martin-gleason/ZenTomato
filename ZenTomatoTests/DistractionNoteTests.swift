import Foundation
import Testing

@testable import ZenTomato

/// Tests for the one rule about what counts as a written sentence.
///
/// The function under test is pure: no database, no timer, no screen. So these
/// tests need no setup at all, and they are the cheapest possible place to pin
/// down the distinction the whole feature rests on — that saying nothing and
/// answering with silence are different facts.
@Suite("DistractionNote")
struct DistractionNoteTests {
  /// A field nobody touched stores nothing at all.
  @Test("emptyIsNothing")
  func emptyIsNothing() {
    #expect(DistractionNote.normalised("") == nil)
  }

  /// A field holding only spaces stores nothing. Somebody who taps into a field
  /// and out again, or whose keyboard inserts a space, has not written a
  /// sentence.
  @Test("whitespaceIsNothing")
  func whitespaceIsNothing() {
    #expect(DistractionNote.normalised("   ") == nil)
    #expect(DistractionNote.normalised("\t") == nil)
  }

  /// The same for newlines, which is the likeliest of the three: the fields are
  /// multi-line, so pressing return is easy and means nothing.
  @Test("newlinesAreNothing")
  func newlinesAreNothing() {
    #expect(DistractionNote.normalised("\n") == nil)
    #expect(DistractionNote.normalised(" \n \n ") == nil)
  }

  /// A real sentence is stored exactly as typed.
  @Test("aSentenceIsKept")
  func aSentenceIsKept() {
    #expect(DistractionNote.normalised("Slack notification about the deploy.")
      == "Slack notification about the deploy.")
  }

  /// Whitespace at the ends is removed — it is an artefact of the text field —
  /// and whitespace *inside* the sentence is left alone, because it is the
  /// person's own.
  @Test("surroundingWhitespaceIsTrimmedAndInnerSpacingIsNot")
  func surroundingWhitespaceIsTrimmedAndInnerSpacingIsNot() {
    #expect(DistractionNote.normalised("  Slack\n") == "Slack")
    #expect(DistractionNote.normalised("\n  Two  spaces  inside.  ") == "Two  spaces  inside.")
  }

  /// **The distinction this function exists for, stated as its own test.**
  ///
  /// Nothing and empty text look identical on a screen and mean opposite things
  /// in the store: nothing means the sentence was skipped, which is a normal
  /// outcome in this app; empty text would mean somebody answered with silence.
  /// If this function ever returned `""` the two would become the same fact,
  /// and no later feature could tell them apart again.
  @Test("nothingIsNotTheSameAsEmptyText")
  func nothingIsNotTheSameAsEmptyText() {
    // Spelled out as a named value rather than compared to a bare literal, so
    // that what is being ruled out is legible: not "some empty thing", but a
    // sentence that was deliberately left blank.
    let deliberatelyEmptySentence: String? = ""
    let result = DistractionNote.normalised("   ")
    #expect(result == nil)
    #expect(result != deliberatelyEmptySentence)
  }
}
