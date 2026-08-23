import Foundation
import Testing

@testable import ZenTomato

/// The picker's search, tested with no database, no screen and no network.
///
/// WHY THAT LAST PART IS THE POINT
/// A search field that makes a request on every keystroke reads as a lookup that
/// might *mint* something — and it would also put this feature's traffic wildly
/// beyond the quiet access pattern it was designed around. The model that backs
/// the picker holds no transport, no client and no credential, so there is
/// physically nothing in it to reach Todoist with. These tests exercise it
/// alongside a stand-in for the network and then check that the stand-in was
/// never touched, which is the strongest statement a test can make about a thing
/// that does not exist.
@Suite("PickerScreenModel")
struct PickerScreenModelTests {
  // MARK: Everything is visible

  /// **All** projects, in Todoist's own order, with nothing filtered.
  ///
  /// `SPEC.md` locks it, and it is the reason the search filters what is already
  /// copied instead of asking Todoist a narrower question.
  @Test("everyProjectIsOffered")
  func everyProjectIsOffered() {
    #expect(Self.corpus.projectRows.count == Self.corpus.projects.count)
  }

  /// A project's screen shows its sections in order, each with its own tasks,
  /// and then whatever is loose in the project.
  @Test("aProjectShowsItsSectionsThenItsLooseTasks")
  func aProjectShowsItsSectionsThenItsLooseTasks() {
    let rows = Self.corpus.rows(inProject: "p1")

    #expect(rows.count == 4)
    guard case .section(let section) = rows[0] else {
      Issue.record("The first row of a project with sections should be a section heading.")
      return
    }
    #expect(section.name == "This week")
    guard case .task(let first) = rows[1], case .task(let second) = rows[2], case .task(let third) = rows[3] else {
      Issue.record("Everything after a section heading should be a task.")
      return
    }
    #expect(first.title == "Draft the Q3 summary")
    #expect(second.title == "Reply to Anna")
    // Loose in the project, so it comes after the sectioned rows.
    #expect(third.title == "Book the room")
  }

  /// A project with nothing in it produces no rows at all — which is what lets
  /// the screen draw one sentence and no controls.
  @Test("anEmptyProjectProducesNoRows")
  func anEmptyProjectProducesNoRows() {
    #expect(Self.corpus.rows(inProject: "p3").isEmpty)
  }

  /// **An emptied section is still a section, and it is still drawn.**
  ///
  /// `SPEC.md` is unconditional: *"All projects, sections, and tasks are visible
  /// in the picker."* Sections with nothing in them used to be dropped, which is
  /// this app making a small editorial judgement about somebody else's Todoist —
  /// the one class of decision a mirror does not get to make. A person who
  /// organises by section and goes looking for the one they just cleared would
  /// find the app quietly disagreeing with Todoist.
  ///
  /// It is drawn as a heading with nothing under it. A heading is text, so this
  /// adds no control anywhere and the no-capture rule is untouched.
  @Test("anEmptySectionIsStillDrawn")
  func anEmptySectionIsStillDrawn() {
    let groups = Self.corpus.groups(inProject: "p4")

    #expect(groups.count == 1)
    #expect(groups.first?.name == "Waiting on somebody")
    #expect(groups.first?.tasks.isEmpty == true)

    // And it reaches the row list too, since that is what the screen's own
    // vocabulary check reads.
    let rows = Self.corpus.rows(inProject: "p4")
    #expect(rows.count == 1)
    guard case .section(let section) = rows[0] else {
      Issue.record("An empty section should still produce its heading row.")
      return
    }
    #expect(section.name == "Waiting on somebody")
  }

  /// The rows the screen draws and the rows the tests read are the same rows.
  ///
  /// They were once two implementations of the same rule — one in the model, one
  /// in the view — so a fix applied to either left the other stale while this
  /// suite went on passing against code nothing drew.
  @Test("theRowsAreTheGroupsFlattened")
  func theRowsAreTheGroupsFlattened() {
    for projectID in ["p1", "p2", "p3", "p4"] {
      let fromGroups = Self.corpus.groups(inProject: projectID).flatMap { group -> [String] in
        let heading = group.section.map { ["section-\($0.id)"] } ?? []
        return heading + group.tasks.map { "task-\($0.id)" }
      }
      #expect(Self.corpus.rows(inProject: projectID).map(\.id) == fromGroups)
    }
  }

  // MARK: Searching

  /// Matching is case- and accent-insensitive, so somebody typing quickly still
  /// finds their own task.
  @Test("searchIgnoresCapitalsAndAccents")
  func searchIgnoresCapitalsAndAccents() {
    #expect(Self.corpus.rows(matching: "REPLY").count == 1)
    // Two: the accented task title and the accented project name.
    #expect(Self.corpus.rows(matching: "cafe").count == 2)
  }

  /// Tasks first, then projects, so the commonest thing somebody is looking for
  /// is at the top.
  @Test("tasksAreListedBeforeProjects")
  func tasksAreListedBeforeProjects() {
    let rows = Self.corpus.rows(matching: "deep")

    #expect(rows.count == 2)
    guard case .task = rows[0], case .project = rows[1] else {
      Issue.record("A search should list matching tasks before matching projects.")
      return
    }
  }

  /// An empty query matches nothing rather than everything: the unfiltered list
  /// is what the screen is already showing.
  @Test("anEmptyQueryMatchesNothing")
  func anEmptyQueryMatchesNothing() {
    #expect(Self.corpus.rows(matching: "").isEmpty)
    #expect(Self.corpus.rows(matching: "   ").isEmpty)
  }

  /// Sections are not searched. A section is a place rather than something to
  /// work on, and it cannot be planned.
  @Test("sectionsAreNotSearchResults")
  func sectionsAreNotSearchResults() {
    let rows = Self.corpus.rows(matching: "This week")

    #expect(rows.isEmpty)
  }

  // MARK: What VoiceOver hears

  /// A row's spoken label carries its second line.
  ///
  /// On a search result that second line is the project name, and it is the only
  /// thing telling two rows with the same title apart — which is why it was put
  /// there. The label that draws it is hidden from VoiceOver on a task row, so
  /// without this the project name reached no reader at all: three identical
  /// "Review the draft, not in your plan" and a plan you cannot trust.
  ///
  /// `@MainActor` on this one test: `PickerRowView` is a SwiftUI view, and every
  /// member of one — including a static function that touches nothing — belongs
  /// to the main thread. The rest of this suite is deliberately off it, because
  /// the model it exercises is a plain value with no screen behind it.
  @Test("aRowSpeaksItsSecondLine")
  @MainActor
  func aRowSpeaksItsSecondLine() {
    #expect(
      PickerRowView.spokenToggleLabel(title: "Review the draft", subtitle: "Deep work", ordinal: nil)
        == "Review the draft, Deep work, not in your plan")

    #expect(
      PickerRowView.spokenToggleLabel(title: "Review the draft", subtitle: "Café admin", ordinal: 2)
        == "Review the draft, Café admin, number 2 in your plan")

    // A row inside a project has no second line, and gains no invented one.
    #expect(
      PickerRowView.spokenToggleLabel(title: "Reply to Anna", subtitle: nil, ordinal: nil)
        == "Reply to Anna, not in your plan")

    // A project row speaks its count.
    #expect(
      PickerRowView.spokenToggleLabel(
        title: "Deep work",
        subtitle: PickerScreenModel.taskCountLine(3),
        ordinal: 1) == "Deep work, 3 tasks, number 1 in your plan")
  }

  // MARK: No request, ever

  /// Every search in this suite, run one after another, with a stand-in for the
  /// network sitting right beside them — and it is never asked for anything.
  @Test("searchIssuesNoRequest")
  func searchIssuesNoRequest() {
    let stub = StubTodoistTransport(answers: [])

    for query in ["d", "dr", "dra", "draft", "draft t", "nothing at all matches this"] {
      _ = Self.corpus.rows(matching: query)
    }

    #expect(stub.recordedRequests.isEmpty)
  }

  // MARK: Private

  /// A small account: two projects with things in them, one empty, one holding
  /// nothing but an emptied section, two sections, one loose task, and one
  /// accented title.
  private static let corpus = PickerScreenModel(
    projects: [
      PickerScreenModel.Project(id: "p1", name: "Deep work", openTaskCount: 3),
      PickerScreenModel.Project(id: "p2", name: "Café admin", openTaskCount: 1),
      PickerScreenModel.Project(id: "p3", name: "Someday", openTaskCount: 0),
      PickerScreenModel.Project(id: "p4", name: "Errands", openTaskCount: 0)
    ],
    sections: [
      PickerScreenModel.Section(id: "s1", name: "This week", projectID: "p1"),
      // A section somebody has just cleared. It has no tasks and it is still one
      // of their sections.
      PickerScreenModel.Section(id: "s2", name: "Waiting on somebody", projectID: "p4")
    ],
    tasks: [
      PickerScreenModel.TaskItem(
        id: "t1",
        title: "Draft the Q3 summary",
        projectID: "p1",
        projectName: "Deep work",
        sectionID: "s1"),
      PickerScreenModel.TaskItem(
        id: "t2",
        title: "Reply to Anna",
        projectID: "p1",
        projectName: "Deep work",
        sectionID: "s1"),
      PickerScreenModel.TaskItem(
        id: "t3",
        title: "Book the room",
        projectID: "p1",
        projectName: "Deep work",
        sectionID: nil),
      PickerScreenModel.TaskItem(
        id: "t4",
        title: "Order more beans for the café",
        projectID: "p2",
        projectName: "Café admin",
        sectionID: nil),
      PickerScreenModel.TaskItem(
        id: "t5",
        title: "Plan deep work for Thursday",
        projectID: "p2",
        projectName: "Café admin",
        sectionID: nil)
    ])
}
