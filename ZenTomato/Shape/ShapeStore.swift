import Foundation

/// The substrate a shape is stored in — three operations and no more.
///
/// **WHY THIS EXISTS, STATED HONESTLY.** It is not here because a test needed a stand-in; the shape
/// store is perfectly testable against a disposable `UserDefaults` suite, and that is still how most
/// of its tests run. It is here because the owner chose, deliberately, to buy sync-readiness now —
/// see the sync-medium delta in `docs/plans/00-deltas.md`. `CLAUDE.md` forbids preparing for work
/// outside the milestone and `D16`'s test asks whether this would be written the same way if the
/// parked feature were never coming. It would not. That is recorded rather than disguised, because
/// the alternative — calling it a testability extraction — is the exact wording
/// `PolishFenceTests.noNewProtocol` names as the drift it watches for.
///
/// **Why the medium and not the store.** Abstracting `ShapeStore` itself would mean writing a second
/// whole implementation for iCloud, duplicating the codec and the cursor. Abstracting the *substrate*
/// leaves `ShapeStore` as the single place that knows what a stored shape is, and
/// `NSUbiquitousKeyValueStore` — the iCloud counterpart, whose API is nearly identical to
/// `UserDefaults` but which is not a `UserDefaults` and so cannot be passed where one is expected —
/// conforms with the same three-line shim below.
///
/// **Deliberately minimal.** Three operations, exactly what a shape store needs, and no generic
/// `Any?` accessor. A wider protocol would become the app's general storage abstraction by
/// gravity, which is a different decision nobody has made.
protocol KeyValueMedium {
  func data(forKey key: String) -> Data?
  func write(_ data: Data, forKey key: String)
  func removeValue(forKey key: String)
}

/// **The app's own medium, and the only place `UserDefaults` is named in shipped code.**
///
/// `data(forKey:)` already matches; the other two are renamed because `UserDefaults.set` takes
/// `Any?` and a protocol witness must match its requirement exactly.
extension UserDefaults: KeyValueMedium {
  func write(_ data: Data, forKey key: String) { set(data, forKey: key) }
  func removeValue(forKey key: String) { removeObject(forKey: key) }
}

/// Where the shape you last fitted lives, until you fit another one.
///
/// **THIS IS THE ONLY FILE IN THE APP THAT MAY NAME `UserDefaults`, AND A TEST ENFORCES IT.**
/// `PolishFenceTests.noNewPersistentSurface` asserts the *set of files* containing the word, not a
/// count of occurrences — a count would stay green while a read moved into `TimerEngine` and one
/// disappeared from here, which is exactly the well-meaning edit this fence exists to stop.
///
/// **WHY A THIRD STORE AT ALL, GIVEN `AppSettings.swift:29` ARGUES AGAINST ONE.** That argument —
/// one store to reason about, one backup story, one place to look — is about *preferences*, and a
/// shape is not one. It is one decision about how to cut up an hour, and there is nothing in it worth
/// restoring from a backup. Ratified as `D32`; the reasoning is `docs/plans/F8.md`, Ruling E.
///
/// **THE LIFETIME WAS RULED AGAIN ON 2026-09-24, AND IT IS NOT WHAT THE FIRST RULING SAID.** This
/// comment used to read *"written when you start, deleted when the sprint ends, never read again"*,
/// and it cited `SessionPlan`'s rule that a stored thing outliving its session becomes a second,
/// competing account of the same day. The owner replaced it: *"the rule to discard a stored shape
/// should last until a new shape is added"*, and *"only the definition — a grace period of 36
/// hours"* for the position in it. The `SessionPlan` argument does not defeat that, and the
/// difference is what the two records claim. Two accounts of **what you are doing now** is the defect;
/// a shape you fitted beside the lengths you usually use is a hierarchy, and `Save to settings` is
/// already the documented way to promote one to the other.
///
/// **ONE KEY, ONE VALUE, ONE SLOT.** There is no dictionary of named shapes here and adding one is
/// its own gate — the store is single-slot and unnamed on purpose, because a second slot turns one
/// sprint's intent into a library of user-authored objects.
///
/// **The medium is injected rather than reached for.** A test hands this a private, disposable
/// suite, so no test can read, write or leave anything in the app's real defaults — the same rule
/// `TestStore` states for the database. A protocol was the other way to make that possible and was
/// not taken: `PolishFenceTests.noNewProtocol` pins the count at ten, an eleventh protocol
/// "extracted for testability" is the precise disguise that fence is watching for, and injecting
/// the real medium tests the real encoder rather than a stand-in for it.
struct ShapeStore {
  /// The one key. Namespaced because a preferences domain is shared with the system.
  static let key = "zentomato.shape"

  private let medium: KeyValueMedium

  /// What the grace period is measured against.
  ///
  /// **Injected rather than read, because the rule it serves is a claim about time** and a test
  /// cannot wait thirty-six hours to make it. The engine's own `TimerClock` was the other candidate
  /// and was not taken: this store is handed to the shape sheet as well, which has no clock, and
  /// widening the sheet's dependencies to give the store the engine's clock would put a timer
  /// abstraction into a screen that does not run a timer.
  private let now: () -> Date

  /// - Parameters:
  ///   - medium: the medium. Defaults to the app's own, which is what the composition root wants and
  ///     what no test should ever be given.
  ///   - now: the clock the 36-hour grace is measured against.
  init(medium: KeyValueMedium = UserDefaults.standard, now: @escaping () -> Date = Date.init) {
    self.medium = medium
    self.now = now
  }

  // MARK: Reading

  /// Everything the store holds, or `nil` when it holds nothing readable — **with a position older
  /// than its grace already dropped.**
  ///
  /// **The staleness rule lives on the read rather than on a sweep, and that is what makes it
  /// total.** A clean-up that ran at launch would leave every other entry point — the sheet reading
  /// the controls, the engine resolving a block at a boundary — able to see a position the rule says
  /// does not exist. Here there is one door, so there is one answer.
  ///
  /// **It rewinds and does not write.** Reading is idempotent, a read cannot fail half-way through a
  /// write, and the value on disk is corrected by the next real write rather than by a side effect
  /// of somebody looking at it. The cost is that the stale cursor stays in the file until then,
  /// which nothing can observe, because nothing reads the file except this method.
  ///
  /// **There is no non-optional overload and no `?? .default`, and that absence is load-bearing.**
  /// A later edit that wants a default has to change a signature, which is visible in a diff,
  /// rather than change an operator, which is not. `F8-M4` is the mutation that proves it.
  func load() -> StoredShape? {
    guard let data = medium.data(forKey: Self.key) else { return nil }
    guard var value = try? JSONDecoder().decode(StoredShape.self, from: data) else { return nil }
    if let run = value.run, run.cursor != 0, !run.isFresh(at: now()) { value.run = run.rewound }
    return value
  }

  /// The shape the engine should follow, if one has been fitted and this build can read it.
  ///
  /// **A cursor of zero is not "no shape", and callers must not read it as one.** Since the owner's
  /// ruling of 2026-09-24 a shape survives its own sprint, so this returns a value between sprints
  /// as well as during one — which is exactly what makes the idle screen announce the shape's first
  /// pomodoro rather than the settings' one. What ends a sprint is `advance()` saying so, not this
  /// going `nil`.
  func runningShape() -> StoredRun? {
    load()?.run
  }

  // MARK: Writing

  /// Replaces everything the store holds.
  func save(_ value: StoredShape) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    medium.write(data, forKey: Self.key)
  }

  /// **Writes a freshly fitted shape**, keeping the controls that are remembered between shapes and
  /// replacing whatever shape was there.
  ///
  /// This is the one and only thing that discards a shape — *"the rule to discard a stored shape
  /// should last until a new shape is added"* — and the name is now the weaker half of the truth: it
  /// is called when a shape is **fitted**, which is before anything is started. `F8`'s note 1 is why
  /// (*"idle should update when the sprint is fitted"*), and the position it writes is zero, so the
  /// distinction costs nothing at the boundary.
  func start(_ shape: SprintShape) {
    let existing = load()
    save(
      StoredShape(
        preset: existing?.preset ?? .balanced,
        endsWithLongBreak: existing?.endsWithLongBreak ?? true,
        run: StoredRun(shape: shape, positionedAt: now())))
  }

  /// Moves the shape on to its next block, and rewinds it once there is no next block.
  ///
  /// **The rewind is keyed on the cursor reaching the end, not on the timer cycle saying the sprint
  /// is over.** With the trailing long break switched off a shape's last block is a focus block,
  /// and the cycle's "sprint ended" signal is raised only by a long break — so an `endsSprint`-keyed
  /// end would never fire for half the shapes this feature can produce, and the shape would run past
  /// its own budget. That is precisely the defect `F8-M3` is named for, which is why the mutation is
  /// run against both settings of the toggle.
  ///
  /// **It returns whether the shape was spent, and the engine uses the answer rather than inferring
  /// it.** Before the owner's ruling the engine read the store twice around this call and took the
  /// value going `nil` as "the sprint ended". A shape that survives its sprint never goes `nil`, so
  /// that inference would have been silently false for every shaped sprint — the engine would have
  /// queued a long break out of `AppSettings` after a shape whose last block was a pomodoro, which
  /// is the 120-runs-135 defect `F8-M7` exists for, arriving by a second door.
  ///
  /// - Returns: `true` when this advance spent the shape's last block.
  @discardableResult
  func advance() -> Bool {
    guard var value = load(), var run = value.run else { return false }
    run.cursor += 1
    run.positionedAt = now()
    let spent = run.isSpent
    value.run = spent ? run.rewound : run
    save(value)
    return spent
  }

  /// **Takes the shape back to its first block and keeps everything else.** Reached when a sprint is
  /// abandoned.
  ///
  /// **Why a stop costs the position when thirty-six hours of silence is the stated rule.** The
  /// position is only meaningful beside the cycle's own tally, and `stop(reason:)` resets that tally
  /// to zero — a shape held at block four against a cycle at pomodoro zero is two accounts of the
  /// same sprint, which is the thing `SessionPlan` refuses by name. The grace period is for the case
  /// where nobody decided anything: the app was killed, the phone was left alone, and the row still
  /// says mid-sprint.
  ///
  /// If the stored value cannot be read at all the whole key goes, because leaving an unreadable
  /// value in place would mean the next read has to decide again what it means — and it already
  /// decided: nothing.
  func rewindRun() {
    guard var value = load() else {
      medium.removeValue(forKey: Self.key)
      return
    }
    guard let run = value.run, run.cursor != 0 else { return }
    value.run = run.rewound
    save(value)
  }
}
