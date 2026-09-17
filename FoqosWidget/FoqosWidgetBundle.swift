//
//  FoqosWidgetBundle.swift
//  FoqosWidget
//
//  Created by Ali Waseem on 2025-03-11.
//

import SwiftUI
import WidgetKit

@main
struct FoqosWidgetBundle: WidgetBundle {
  /// Live Activities only. The home-screen/Control widget was cut before 1.0: it was inherited
  /// wholesale, never got the world treatment (it painted itself flat green/orange), and its tap
  /// target pointed at a domain this app does not own.
  var body: some Widget {
    FoqosWidgetLiveActivity()
  }
}
