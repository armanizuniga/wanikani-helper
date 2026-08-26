// Entry point for the WaniWidget extension. Hosts a single Lock Screen widget
// that surfaces WaniKani vocabulary the user has learned.
import WidgetKit
import SwiftUI

@main
struct WaniWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockScreenWordWidget()
    }
}
