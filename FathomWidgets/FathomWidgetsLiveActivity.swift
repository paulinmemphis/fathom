//
//  FathomWidgetsLiveActivity.swift
//  FathomWidgets
//
//  Created by Paul Thomas on 6/10/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FathomWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FathomWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FathomWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FathomWidgetsAttributes {
    fileprivate static var preview: FathomWidgetsAttributes {
        FathomWidgetsAttributes(name: "World")
    }
}

extension FathomWidgetsAttributes.ContentState {
    fileprivate static var smiley: FathomWidgetsAttributes.ContentState {
        FathomWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FathomWidgetsAttributes.ContentState {
         FathomWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FathomWidgetsAttributes.preview) {
   FathomWidgetsLiveActivity()
} contentStates: {
    FathomWidgetsAttributes.ContentState.smiley
    FathomWidgetsAttributes.ContentState.starEyes
}
