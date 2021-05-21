//
//  AudioStreamAirpodsApp.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/13.
//

import SwiftUI

@main
struct AudioStreamAirpodsApp: App {
    var sensorVM = SensorViewModel()
    var robot = RobotScene()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sensorVM)
                .environmentObject(robot)
        }
    }
}
