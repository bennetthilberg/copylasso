import SwiftUI

@main
struct CopyLassoApp: App {
  var body: some Scene {
    WindowGroup {
      #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--g07-selection-spike") {
          SelectionOverlaySpikeView()
        } else if ProcessInfo.processInfo.arguments.contains("--g06-capture-spike") {
          ScreenCaptureSpikeView()
        } else {
          ContentView()
        }
      #else
        ContentView()
      #endif
    }
  }
}
