import Foundation

/// The two keys that cross between the phone and the wrist.
///
/// One definition, compiled into both targets, because a string typed twice is a
/// string that eventually differs — and a mismatch here fails silently: the
/// payload arrives, the key does not match, nothing is decoded, and no error is
/// raised anywhere.
enum WatchLinkKeys {
  static let tap = "tap"
  static let state = "state"
}
