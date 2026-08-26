import Foundation
import MetricKit

/// Records why the app stopped responding, on the device, and nowhere else.
///
/// WHY THIS EXISTS
/// `docs/crashes/ZenTomato-2026-08-26-134602.ips` — the watchdog killed the app
/// after ten seconds of not answering, and the only reason anyone could read that
/// report is that the phone happened to be plugged into the machine that built
/// it. A development build's crash reports live on the device and nowhere else.
///
/// **MetricKit is Apple's own answer, and it costs nothing at runtime.** iOS
/// gathers the diagnostics itself and hands them over in a batch, roughly once a
/// day and on the next launch after an incident. There is no sampling loop here,
/// no timer, and no work on any hot path — this object is a mailbox, and the
/// postman is the operating system.
///
/// **`MXHangDiagnostic` is the one that matters.** It reports a hang *with the
/// stack that caused it and how long it lasted*, and iOS notices hangs well below
/// the ten seconds at which the watchdog stops asking politely. The blocking read
/// that killed the app would have appeared here as a hang first.
///
/// WHAT THIS DELIBERATELY DOES NOT DO
/// **Nothing is transmitted.** `SPEC.md` says local only and no analytics, and a
/// crash reporter is the single most natural place for that rule to be broken by
/// accident. Payloads are written into this app's own container. They leave the
/// device when the owner fetches them off it, and by no other route.
///
/// **It has no screen and no setting.** `AppSettings` still holds six values.
/// This is not a feature; it is a flight recorder.
final class HangReporter: NSObject, MXMetricManagerSubscriber {
  // MARK: Lifecycle

  /// Starts listening. Cheap enough to call at launch: it registers and returns.
  static func start() -> HangReporter {
    let reporter = HangReporter()
    MXMetricManager.shared.add(reporter)
    return reporter
  }

  deinit {
    MXMetricManager.shared.remove(self)
  }

  // MARK: Receiving

  /// Diagnostics for a past incident, handed over by iOS.
  ///
  /// Everything the payload knows is already in its JSON, so this writes that
  /// verbatim rather than picking it apart — a summary written today is a summary
  /// that omits the field tomorrow's bug needed.
  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    for payload in payloads {
      Self.write(payload.jsonRepresentation(), named: "diagnostic-\(Self.fileStamp(for: payload)).json")
    }
  }

  /// Metrics rather than diagnostics — daily aggregates. Deliberately ignored.
  ///
  /// They describe performance over time rather than an incident, and keeping
  /// them would be the first step towards the analytics `SPEC.md` forbids.
  func didReceive(_ payloads: [MXMetricPayload]) {}

  // MARK: Private

  /// Where the recorder writes: inside this app's container, so it is deleted
  /// with the app and is reachable with `devicectl` when something goes wrong.
  private static var directory: URL? {
    // `urls(for:in:)` rather than the `url(for:…)` overload, which takes a
    // parameter whose name is one of the four Todoist write verbs
    // `TodoistEndpointTests` forbids by regex across the app's sources. The fence
    // is right to be blunt — it is holding a rule in `CLAUDE.md` that must not be
    // negotiable — and this call does the same job without arguing with it.
    guard let support = FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else { return nil }
    let directory = support.appending(path: "Diagnostics", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// The payload's own time window, so the file name says when the incident was
  /// rather than when it happened to be delivered — those can be a day apart.
  private static func fileStamp(for payload: MXDiagnosticPayload) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return formatter.string(from: payload.timeStampEnd)
  }

  /// Writes one payload, and never disturbs the app if it cannot.
  ///
  /// **A flight recorder that can crash the aircraft is worse than none**, so
  /// every failure here is swallowed. There is nothing a person could do about a
  /// diagnostics file failing to write, and nothing worth interrupting them for.
  private static func write(_ data: Data, named name: String) {
    guard let directory else { return }
    try? data.write(to: directory.appending(path: name), options: .atomic)
    prune(in: directory)
  }

  /// Keeps the most recent twenty and deletes the rest.
  ///
  /// Unbounded diagnostics are a disk-space leak in a directory nobody looks at,
  /// and `MXDiskWriteExceptionDiagnostic` exists precisely because iOS notices
  /// apps that do this.
  private static func prune(in directory: URL) {
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil) else { return }
    let oldestFirst = files
      .filter { $0.lastPathComponent.hasPrefix("diagnostic-") }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard oldestFirst.count > 20 else { return }
    for file in oldestFirst.prefix(oldestFirst.count - 20) {
      try? FileManager.default.removeItem(at: file)
    }
  }
}
