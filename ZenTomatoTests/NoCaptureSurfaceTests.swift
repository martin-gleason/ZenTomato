import Foundation
import Testing

@testable import ZenTomato

/// The standing no-capture rule, as a test rather than as a promise.
///
/// THE RULE
/// `CLAUDE.md`: *"The app never accepts a new task from the user. This is a
/// standing rule from the owner's productivity system, not a feature gap."*
/// Tasks are made in Todoist. This app reads them and, once, ticks one off.
///
/// THE TWO PLACES IT COULD BREAK, AND WHY THEY ARE BOTH HERE
///
///   1. **The token field.** It is a text field on a screen in an app that
///      otherwise has almost none, and it is the one input this feature adds.
///      It accepts a credential, and everything about it has to say so.
///   2. **The picker's search.** An empty result is exactly where every other
///      app on the phone offers to create the thing you just typed — not because
///      anybody decides to, but because the framework's own empty-state view has
///      a slot for an action and every tutorial fills it.
///
/// HOW A TEST CAN CHECK THIS AT ALL
/// Two ways, and both are used below:
///
///   * **By shape.** The picker's model can produce exactly three kinds of row.
///     The test below switches over that list with no catch-all clause, so
///     adding a fourth kind stops this file compiling. That is enforcement, not
///     observation.
///   * **By words.** Every sentence these screens can put in front of somebody
///     is collected and checked for the vocabulary of creation. A control that
///     offered to make a task would have to be labelled, and this is what would
///     catch the label.
///
/// `@MainActor` on the whole suite, because the token screen's state is a
/// main-thread type like every other screen model in this app.
@Suite("NoCaptureSurface")
@MainActor
struct NoCaptureSurfaceTests {
  // MARK: By shape

  /// The picker can draw a project, a section, or a task. **There is no fourth
  /// kind of row**, in any state — not at the end of a list, not under a search
  /// with no matches, not in an empty project.
  ///
  /// This switch has no `default`, which is the whole mechanism: a new case on
  /// `PickerScreenModel.Row` stops the test bundle compiling, and the only way
  /// past it is for somebody to change this test in a diff the owner reads.
  @Test("thePickerCanOnlyDrawProjectsSectionsAndTasks")
  func thePickerCanOnlyDrawProjectsSectionsAndTasks() {
    let everyRow = Self.corpus.projectRows
      + Self.corpus.rows(inProject: "p1")
      + Self.corpus.rows(matching: "draft")

    for row in everyRow {
      switch row {
      case .project, .section, .task:
        continue
      }
    }

    #expect(everyRow.isEmpty == false)
  }

  /// A search with no matches produces **no rows at all** — so there is nothing
  /// for a trailing "create this" row to be appended to.
  @Test("aSearchWithNoMatchesOffersNothing")
  func aSearchWithNoMatchesOffersNothing() {
    #expect(Self.corpus.rows(matching: "deploy the thing").isEmpty)
  }

  /// An empty project produces no rows, so the screen has one sentence to draw
  /// and nothing else.
  @Test("anEmptyProjectOffersNothing")
  func anEmptyProjectOffersNothing() {
    #expect(Self.corpus.rows(inProject: "p3").isEmpty)
    #expect(PickerScreenModel.emptyProjectMessage == "No tasks in this project.")
  }

  /// A project holding nothing but an emptied section draws that section's
  /// heading **and** the empty-project sentence — and still offers nothing.
  ///
  /// A heading is text. Drawing it satisfies `SPEC.md`'s "all sections are
  /// visible" without adding a control anywhere, which is why the two rules do
  /// not collide.
  @Test("anEmptySectionIsAHeadingAndNotAnInvitation")
  func anEmptySectionIsAHeadingAndNotAnInvitation() {
    let rows = Self.corpus.rows(inProject: "p4")

    #expect(rows.count == 1)
    for row in rows {
      switch row {
      case .section(let section):
        for word in Self.creationWords {
          #expect(section.name.range(of: word, options: .caseInsensitive) == nil)
        }
      case .project, .task:
        Issue.record("A project holding only an emptied section can draw nothing but that heading.")
      }
    }
  }

  // MARK: By words

  /// Nothing this feature can say invites making a task.
  ///
  /// The words are the ones a create control would have to be labelled with. The
  /// check is deliberately blunt: it would object to a perfectly innocent
  /// sentence containing "add", and that is the right trade on the one rule this
  /// project cares most about — an objection costs a rewording, and a miss costs
  /// the rule.
  @Test("noSentenceOnThesePickerScreensInvitesCreatingATask")
  func noSentenceOnThesePickerScreensInvitesCreatingATask() {
    for sentence in Self.everySentenceThePickerCanSay {
      for word in Self.creationWords {
        #expect(
          sentence.range(of: word, options: .caseInsensitive) == nil,
          "“\(sentence)” contains “\(word)”.")
      }
    }
  }

  /// The one place tasks come from is named out loud, in the place every other
  /// app puts a button.
  @Test("theNoMatchStateSaysWhereTasksComeFrom")
  func theNoMatchStateSaysWhereTasksComeFrom() {
    #expect(PickerScreenModel.noMatchHeading == "No tasks match that.")
    #expect(PickerScreenModel.noMatchOrigin == "Tasks are created in Todoist, not here.")
    #expect(PickerScreenModel.noMatchDetail(for: "deploy the thing").contains("deploy the thing"))
  }

  /// The search field's prompt is a verb that **reads**.
  @Test("theSearchPromptIsAVerbThatReads")
  func theSearchPromptIsAVerbThatReads() {
    #expect(PickerScreenModel.searchPrompt == "Search your Todoist tasks")
  }

  // MARK: The history screen

  /// **F6 adds four screens and none of them accepts typing.**
  ///
  /// This is the second place the rule was most likely to break, after the
  /// picker's search. A history screen is where a search box over the log
  /// belongs in every other app on the phone, and where "add a note to this
  /// day" reads as an obvious kindness. Neither exists: the distraction
  /// sentences are read-only here, and the one place a sentence is ever written
  /// is the end-of-block sheet, at the moment the block ends.
  ///
  /// The absence of the *control* is checked mechanically by `StatsFenceTests`,
  /// which greps the four directories for every text-entry type. This checks the
  /// other half — the **vocabulary** — because a control that invited making
  /// something would have to be labelled, and a label is what this catches.
  @Test("noSentenceOnTheHistoryScreenInvitesCreatingATask")
  func noSentenceOnTheHistoryScreenInvitesCreatingATask() {
    for sentence in Self.everySentenceTheHistoryScreenCanSay {
      for word in Self.creationWords {
        #expect(
          sentence.range(of: word, options: .caseInsensitive) == nil,
          "“\(sentence)” contains “\(word)”.")
      }
    }
  }

  /// The empty state states a fact and never asks anybody to do anything.
  ///
  /// Somebody who installed the app this morning is in this state, and so is
  /// somebody with four hundred pomodoros who chose last February. A screen that
  /// answered either of them with an invitation would be a capture surface with
  /// better manners.
  @Test("theHistoryScreensEmptyStateOffersNothingToDo")
  func theHistoryScreensEmptyStateOffersNothingToDo() {
    let empty = [
      StatsScreenModel.emptyHeading(for: StatsRange.day(StatsDay(year: 2026, month: 8, day: 23, weekday: 1))),
      StatsScreenModel.emptyDetail,
      StatsScreenModel.emptyOrigin
    ]

    for sentence in empty {
      for word in Self.creationWords + ["start a", "let's", "try "] {
        #expect(
          sentence.range(of: word, options: .caseInsensitive) == nil,
          "“\(sentence)” invites rather than states.")
      }
    }
  }

  // MARK: The credential field

  /// The token screen's own state can hold a credential and can do exactly one
  /// thing with it. It has no notion of a task, and with nothing behind it —
  /// which is the state a preview is in — it cannot even connect.
  @Test("theTokenScreenAcceptsACredentialAndNothingElse")
  func theTokenScreenAcceptsACredentialAndNothingElse() async {
    let model = SignInScreenModel()

    // Whitespace is not a credential, and a trimmed paste is what gets judged.
    model.token = "   "
    #expect(model.canConnect == false)

    // A paste arrives trimmed of the newline it usually comes with, and it is
    // revealed so somebody can see what landed.
    model.paste(["  not-a-real-token\n"])
    #expect(model.token == "not-a-real-token")
    #expect(model.isRevealed)
    #expect(model.canConnect)

    // With no store and no copy of Todoist behind it there is nothing it can
    // do, and it says so by doing nothing rather than by pretending.
    #expect(await model.connect() == false)
  }

  /// The wording a revoked credential lands on says "revoked", never "an error
  /// occurred" — and never a character of the credential itself.
  @Test("theRevokedWordingNamesWhatHappened")
  func theRevokedWordingNamesWhatHappened() {
    let message = SignInScreenModel.Banner.revoked.message

    #expect(message.contains("revoked"))
    #expect(message.contains("not-a-real-token") == false)
    for word in Self.creationWords {
      #expect(message.range(of: word, options: .caseInsensitive) == nil)
    }
  }

  // MARK: Private

  /// The vocabulary a control that made a task would have to use.
  ///
  /// "Create" is checked as a whole word through the phrases below rather than
  /// as a substring, because the one sentence that is *allowed* to contain it is
  /// the one that says tasks are created somewhere else — and that sentence is
  /// checked separately, by name.
  private static let creationWords = ["add ", "new task", "create a", "create your", "compose", "+ "]

  /// Every sentence these screens can put in front of somebody.
  ///
  /// **It used to be five of about fifteen**, and the ten it was missing were
  /// the empty states — which is precisely where a create affordance gets added.
  /// The fix was not to lengthen this array but to move the words: every
  /// user-facing string in the picker stack now lives on `PickerScreenModel`
  /// beside the ones that were already there, and the views name them. A
  /// sentence written inline in a view would be a sentence outside the pattern
  /// the whole file is built on, which is a visible thing in a diff rather than
  /// an invisible one.
  private static let everySentenceThePickerCanSay = [
    PickerScreenModel.searchPrompt,
    PickerScreenModel.emptyProjectMessage,
    PickerScreenModel.noMatchHeading,
    PickerScreenModel.noMatchOrigin,
    PickerScreenModel.noMatchDetail(for: "deploy the thing"),
    PickerScreenModel.projectsHeader,
    PickerScreenModel.resultsHeader,
    PickerScreenModel.looseGroupName,
    PickerScreenModel.nothingPlannedYet,
    PickerScreenModel.sessionPlanTitle,
    PickerScreenModel.inOrderHeader,
    PickerScreenModel.emptyPlanHeading,
    PickerScreenModel.emptyPlanDetail,
    PickerScreenModel.nothingMirroredHeading,
    PickerScreenModel.nothingMirroredExplanation,
    PickerScreenModel.nothingMirroredReassurance,
    PickerScreenModel.tryAgain,
    PickerScreenModel.taskCountLine(0),
    PickerScreenModel.taskCountLine(1),
    PickerScreenModel.taskCountLine(3),
    PickerScreenModel.planSummary(count: 1),
    PickerScreenModel.planSummary(count: 3),
    PickerScreenModel.nextInPlan("Draft the Q3 summary")
  ]

  /// Every sentence F6's screens can put in front of somebody.
  ///
  /// Collected here for the same reason the picker's list is: a sentence typed
  /// inline in a view is a sentence outside the pattern this file checks, and
  /// the picker's list was once five of about fifteen — the ten it was missing
  /// being the empty states, which is precisely where a create affordance gets
  /// added.
  private static let everySentenceTheHistoryScreenCanSay = [
    StatsScreenModel.screenTitle,
    StatsScreenModel.todayKicker,
    StatsScreenModel.daysHeader,
    StatsScreenModel.projectsHeader,
    StatsScreenModel.tasksHeader,
    StatsScreenModel.rangeHeader,
    StatsScreenModel.rangeStartLabel,
    StatsScreenModel.rangeEndLabel,
    StatsScreenModel.rangeResetLabel,
    StatsScreenModel.doneLabel,
    StatsScreenModel.todayIsAlwaysToday,
    StatsScreenModel.emptyDetail,
    StatsScreenModel.emptyOrigin,
    StatsScreenModel.exportHint,
    StatsScreenModel.rangeHint,
    StatsScreenModel.openDayHint,
    StatsScreenModel.todaySpokenLabel,
    StatsScreenModel.exportUnavailable,
    StatsDaySheet.header,
    StatsDaySheet.internalWord,
    StatsDaySheet.externalWord,
    StatsDaySheet.noNote,
    StatsWords.noTask,
    StatsWords.noProject,
    StatsMarkdown.nothingRecorded
  ]

  private static let corpus = PickerScreenModel(
    projects: [
      PickerScreenModel.Project(id: "p1", name: "Deep work", openTaskCount: 1),
      PickerScreenModel.Project(id: "p3", name: "Someday", openTaskCount: 0),
      PickerScreenModel.Project(id: "p4", name: "Errands", openTaskCount: 0)
    ],
    sections: [
      PickerScreenModel.Section(id: "s1", name: "This week", projectID: "p1"),
      PickerScreenModel.Section(id: "s2", name: "Waiting on somebody", projectID: "p4")
    ],
    tasks: [
      PickerScreenModel.TaskItem(
        id: "t1",
        title: "Draft the Q3 summary",
        projectID: "p1",
        projectName: "Deep work",
        sectionID: "s1")
    ])
}
