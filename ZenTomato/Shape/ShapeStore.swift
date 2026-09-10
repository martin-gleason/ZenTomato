import Foundation

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

  private let defaults: UserDefaults

  /// - Parameter defaults: the medium. Defaults to the app's own, which is what the composition
  ///   root wants and what no test should ever be given.
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  // MARK: Reading

  /// Everything the store holds, or `nil` when it holds nothing readable.
  ///
  /// **There is no non-optional overload and no `?? .default`, and that absence is load-bearing.**
  /// A later edit that wants a default has to change a signature, which is visible in a diff,
  /// rather than change an operator, which is not. `F8-M4` is the mutation that proves it.
  func load() -> StoredShape? {
    guard let data = defaults.data(forKey: Self.key) else { return nil }
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
    defaults.set(data, forKey: Self.key)
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
      defaults.removeObject(forKey: Self.key)
      return
    }
    guard value.run != nil else { return }
    value.run = nil
    save(value)
  }
}
