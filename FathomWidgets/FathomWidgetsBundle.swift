//
//  FathomWidgetsBundle.swift
//  FathomWidgets
//
//  Created by Paul Thomas on 6/10/25.
//

import WidgetKit
import SwiftUI

// This file is now the single entry point for the widget extension.
@main
struct FathomWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // This now correctly finds and includes the FathomWidgets struct.
        FathomWidgets()
    }
}
