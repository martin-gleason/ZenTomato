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

/// Where a shape lives between the moment it is calculated and the moment its sprint ends.
///
/// **THIS IS THE ONLY FILE IN THE APP THAT MAY NAME `UserDefaults`, AND A TEST ENFORCES IT.**
/// `PolishFenceTests.noNewPersistentSurface` asserts the *set of files* containing the word, not a
/// count of occurrences — a count would stay green while a read moved into `TimerEngine` and one
/// disappeared from here, which is exactly the well-meaning edit this fence exists to stop.
///
/// **WHY A THIRD STORE AT ALL, GIVEN `AppSettings.swift:29` ARGUES AGAINST ONE.** That argument —
/// one store to reason about, one backup story, one place to look — is about *preferences*, and a
/// shape is not one. It is one sprint's worth of intent: written when you start, deleted when the
/// sprint ends, never read again. It has no backup story to be inconsistent with because there is
/// nothing in it worth restoring. `SessionPlan`'s own doc comment makes this argument for the
/// neighbouring case: a stored thing that outlives its session becomes a second, competing account
/// of the same day. Ratified as `D32`; the reasoning is `docs/plans/F8.md`, Ruling E.
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

  /// - Parameter defaults: the medium. Defaults to the app's own, which is what the composition
  ///   root wants and what no test should ever be given.
  init(medium: KeyValueMedium = UserDefaults.standard) {
    self.medium = medium
  }

  // MARK: Reading

  /// Everything the store holds, or `nil` when it holds nothing readable.
  ///
  /// **There is no non-optional overload and no `?? .default`, and that absence is load-bearing.**
  /// A later edit that wants a default has to change a signature, which is visible in a diff,
  /// rather than change an operator, which is not. `F8-M4` is the mutation that proves it.
  func load() -> StoredShape? {
    guard let data = medium.data(forKey: Self.key) else { return nil }
    return try? JSONDecoder().decode(StoredShape.self, from: data)
  }

  /// The shape that is running, if one is and if this build can read it.
  func runningShape() -> StoredRun? {
    load()?.run
  }

  // MARK: Writing

  /// Replaces everything the store holds.
  func save(_ value: StoredShape) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    medium.write(data, forKey: Self.key)
  }

  /// Writes a freshly calculated shape, keeping the controls that are remembered between shapes.
  func start(_ shape: SprintShape) {
    let existing = load()
    save(
      StoredShape(
        preset: existing?.preset ?? .balanced,
        endsWithLongBreak: existing?.endsWithLongBreak ?? true,
        run: StoredRun(shape: shape)))
  }

  /// Moves the shape on to its next block, and clears it once there is no next block.
  ///
  /// **The clear is keyed on the cursor reaching the end, not on the timer cycle saying the sprint
  /// is over.** With the trailing long break switched off a shape's last block is a focus block,
  /// and the cycle's "sprint ended" signal is raised only by a long break — so an `endsSprint`-keyed
  /// clear would never fire for half the shapes this feature can produce, and the shape would
  /// outlive its sprint for ever. That is precisely the defect `F8-M3` is named for, which is why
  /// the mutation is run against both settings of the toggle.
  func advance() {
    guard var value = load(), var run = value.run else { return }
    run.cursor += 1
    value.run = run.isSpent ? nil : run
    save(value)
  }

  /// Forgets the running shape and keeps the controls.
  ///
  /// Reached when a sprint is abandoned. If the stored value cannot be read at all the whole key
  /// goes, because leaving an unreadable value in place would mean the next read has to decide
  /// again what it means — and it already decided: nothing.
  func clearRun() {
    guard var value = load() else {
      medium.removeValue(forKey: Self.key)
      return
    }
    guard value.run != nil else { return }
    value.run = nil
    save(value)
  }
}
