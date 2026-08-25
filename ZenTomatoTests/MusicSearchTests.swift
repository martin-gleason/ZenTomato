import Foundation
import Testing

@testable import ZenTomato

/// Search over the music library, and the condition it exists under.
///
/// **WHY THIS FEATURE HAD TO BE ARGUED FOR AT ALL.** `MusicPickerScreenModel`'s
/// doc comment stated, in bold, that *"the ratified scope fence forbids it by
/// name — a text field of any kind in this feature is a finding."* That sentence
/// was false when it was written. `F4-contract.md` §7 says the opposite:
///
/// > Page it, and if paging turns out to need a search field, that field must
/// > offer nothing when it finds nothing — `NoCaptureSurfaceTests` already covers
/// > the idiom and the same test must cover this picker.
///
/// Paging did turn out not to be enough: the owner scrolled a real library for
/// over two minutes. The lesson worth keeping is not about music — it is that a
/// confident sentence in a code comment is not a ratified decision, and this one
/// nearly closed an investigation the owner had already opened.
///
/// So this suite does two jobs: it tests the filter, and it discharges the
/// condition the contract attached to the field existing.
@Suite("MusicSearch")
struct MusicSearchTests {
  // MARK: The filter

  /// `matchesAnywhereInTheTitle` — not just the start.
  ///
  /// People remember a word from the middle of a name far more reliably than they
  /// remember how it begins, and a prefix-only search over a library of a few
  /// hundred playlists would look like it was broken.
  @Test("matchesAnywhereInTheTitle")
  func matchesAnywhereInTheTitle() {
    let model = Self.library

    #expect(Self.titles(model.playlistRows(matching: "piano")) == ["Late Night Piano · Studio"])
    #expect(Self.titles(model.playlistRows(matching: "Studio")) == ["Late Night Piano · Studio"])
  }

  /// `ignoresCapitalsAndAccents` — the same rule the Todoist picker uses.
  @Test("ignoresCapitalsAndAccents")
  func ignoresCapitalsAndAccents() {
    let model = Self.library

    #expect(Self.titles(model.playlistRows(matching: "CAFÉ")) == ["Café del Mar"])
    #expect(Self.titles(model.playlistRows(matching: "cafe")) == ["Café del Mar"])
    #expect(Self.titles(model.playlistRows(matching: "dEl mAr")) == ["Café del Mar"])
  }

  /// `anEmptyQueryGivesTheLibraryBack` — the opposite default to Todoist's, on purpose.
  ///
  /// `PickerScreenModel.rows(matching:)` returns **nothing** for an empty query,
  /// because that screen shows a project tree until somebody searches. Here the
  /// library *is* the screen: blanking the field must give it back rather than
  /// empty it. Getting this backwards would make clearing the field look like the
  /// library had been lost.
  @Test("anEmptyQueryGivesTheLibraryBack")
  func anEmptyQueryGivesTheLibraryBack() {
    let model = Self.library

    for nothingTyped in ["", "   ", "\n", " \t "] {
      #expect(model.playlistRows(matching: nothingTyped).count == model.playlistRows.count)
      #expect(model.songRows(matching: nothingTyped).count == model.songRows.count)
      #expect(model.hasNoMatches(for: nothingTyped) == false)
    }
  }

  /// `bothListsFilterTogether` — and `hasNoMatches` asks about both at once.
  ///
  /// A screen that said "nothing matches" while three songs matched underneath
  /// would be wrong in the most annoying possible way.
  @Test("bothListsFilterTogether")
  func bothListsFilterTogether() {
    let model = Self.library

    #expect(model.playlistRows(matching: "rain").isEmpty)
    #expect(Self.titles(model.songRows(matching: "rain")) == ["Rain on Tin"])
    #expect(model.hasNoMatches(for: "rain") == false, "Songs matched; the screen must not say nothing did.")
    #expect(model.hasNoMatches(for: "nothing whatsoever like this"))
  }

  /// `aBigLibraryNarrowsToTheOneYouWanted` — the actual complaint, at scale.
  ///
  /// Four hundred playlists is the shape of the owner's library. This is the
  /// measurement that says the feature works: one query, one row.
  @Test("aBigLibraryNarrowsToTheOneYouWanted")
  func aBigLibraryNarrowsToTheOneYouWanted() {
    var playlists = (1...400).map {
      MusicSelection(kind: .playlist, identifier: "p.\($0)", title: "Playlist \($0)")
    }
    playlists.append(MusicSelection(kind: .playlist, identifier: "p.x", title: "Thesis — deep work"))
    let model = MusicPickerScreenModel(playlists: playlists, songs: [])

    #expect(Self.titles(model.playlistRows(matching: "thesis")) == ["Thesis — deep work"])
  }

  // MARK: Paging, which the filter sits on top of

  /// `filteringDoesNotOutrunThePaging` — the defect this feature could plausibly ship.
  ///
  /// The reveal counters are **counts, not positions**. Four hundred rows narrowed
  /// to three, with the counter still reading one hundred, means `hasMore` reports
  /// nothing left to reveal — and when the field is cleared the list is stuck
  /// showing one page with no way to grow. The view resets the counters on every
  /// change; this states what that reset has to achieve.
  @Test("filteringDoesNotOutrunThePaging")
  func filteringDoesNotOutrunThePaging() {
    let model = Self.bigLibrary
    let all = model.playlistRows
    let narrowed = model.playlistRows(matching: "Thesis")

    // Scrolled well into the unfiltered list.
    #expect(MusicPickerScreenModel.hasMore(all, shown: 100))

    // After a reset to one page, the narrowed list is fully drawn and asks for no
    // more — which is the state the view must arrive at.
    #expect(narrowed.count < MusicPickerScreenModel.pageSize)
    #expect(MusicPickerScreenModel.hasMore(narrowed, shown: MusicPickerScreenModel.pageSize) == false)
    #expect(MusicPickerScreenModel.page(narrowed, shown: MusicPickerScreenModel.pageSize).count == narrowed.count)

    // And clearing the field can grow again from one page.
    #expect(MusicPickerScreenModel.hasMore(all, shown: MusicPickerScreenModel.pageSize))
  }

  /// `theViewResetsThePagingWhenTheQueryChanges` — the reset actually exists.
  ///
  /// The test above proves what the reset must achieve; this proves the view does
  /// it. Without reading the source there is no way to tell the two apart, and a
  /// correct model with a view that never resets is exactly the shipped bug.
  @Test("theViewResetsThePagingWhenTheQueryChanges")
  func theViewResetsThePagingWhenTheQueryChanges() throws {
    let picker = Self.stripped(try Self.source("ZenTomato/Views/MusicPickerView.swift"))

    guard let change = picker.range(of: ".onChange(of: query)") else {
      Issue.record("The picker no longer resets its paging when the query changes.")
      return
    }
    let body = String(picker[change.upperBound...].prefix(200))
    #expect(body.contains("shownPlaylists = MusicPickerScreenModel.pageSize"))
    #expect(body.contains("shownSongs = MusicPickerScreenModel.pageSize"))
  }

  // MARK: What a filter must not hide

  /// `theChosenItemSurvivesAFilter` — F4e-T5, which needed no code.
  ///
  /// **The risk:** something is chosen, a query is typed that excludes it, and the
  /// tick silently vanishes from a list still claiming to be the picker. Somebody
  /// then reasonably concludes their choice was lost.
  ///
  /// It cannot happen, and not by luck. The picker already draws a **"Now chosen"**
  /// section above the library, for a reason F4 recorded — an item that has left
  /// the library entirely would otherwise disappear with nowhere to report it. That
  /// section sits outside `library` in the view body, so the filter never reaches
  /// it. The plan listed this as a task; the answer was that F4's own handling of a
  /// different problem had already covered it.
  ///
  /// This reads the source, because the guarantee is structural: it lives in the
  /// order of the body, and a tidy-up that moved the chosen section inside the
  /// filtered lists would silently reintroduce exactly the risk above.
  @Test("theChosenItemSurvivesAFilter")
  func theChosenItemSurvivesAFilter() throws {
    let picker = Self.stripped(try Self.source("ZenTomato/Views/MusicPickerView.swift"))
    guard let body = picker.range(of: "var body: some View {"),
          let end = picker.range(of: "\n    }\n", range: body.upperBound..<picker.endIndex) else {
      Issue.record("The picker's body is no longer where this test reads it.")
      return
    }
    let lines = picker[body.upperBound..<end.lowerBound]
      .components(separatedBy: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }

    let chosen = try #require(lines.firstIndex(of: "nowChosenSection(chosen)"))
    let library = try #require(lines.firstIndex(of: "library"))
    #expect(
      chosen < library,
      "The chosen item is drawn inside the filtered library, so a query can hide it.")
  }

  // MARK: Private

  private static let library = MusicPickerScreenModel(
    playlists: [
      MusicSelection(kind: .playlist, identifier: "p.1", title: "Late Night Piano · Studio"),
      MusicSelection(kind: .playlist, identifier: "p.2", title: "Café del Mar"),
      MusicSelection(kind: .playlist, identifier: "p.3", title: "Deep Focus")
    ],
    songs: [
      MusicSelection(kind: .song, identifier: "s.1", title: "Rain on Tin"),
      MusicSelection(kind: .song, identifier: "s.2", title: "Windmills")
    ])

  private static let bigLibrary = MusicPickerScreenModel(
    playlists: (1...400).map {
      MusicSelection(kind: .playlist, identifier: "p.\($0)", title: "Playlist \($0)")
    } + [MusicSelection(kind: .playlist, identifier: "p.x", title: "Thesis — deep work")],
    songs: [])

  private static func titles(_ rows: [MusicPickerScreenModel.Row]) -> [String] {
    rows.map(\.selection.title)
  }

  private static func stripped(_ text: String) -> String {
    text
      .components(separatedBy: "\n")
      .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false }
      .joined(separator: "\n")
  }

  private static func source(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appending(path: path), encoding: .utf8)
  }
}
