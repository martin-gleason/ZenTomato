import SwiftUI
import WidgetKit

/// The second program that ships inside ZenTomato.
///
/// WHAT THIS IS, FOR A READER WHO DOES NOT WRITE SWIFT
/// The countdown that appears on a locked phone, and the little capsule around
/// the front camera, are not drawn by the app. iOS draws them, by running a
/// separate miniature program that lives inside the app's package. This file is
/// that program's front door: it exists to say "here is the list of things I know
/// how to draw", and there is exactly one thing on the list.
///
/// It cannot see the app's database, cannot see the timer, and cannot ask the app
/// anything. Everything it draws is handed to it by iOS along with the alarm —
/// see `FocusAlarmMetadata`.
///
/// `@main` marks it as the starting point of that second program, the same way
/// `ZenTomatoApp` is the starting point of the app itself.
@main
struct ZenTomatoActivityBundle: WidgetBundle {
  var body: some Widget {
    BlockLiveActivity()
  }
}
