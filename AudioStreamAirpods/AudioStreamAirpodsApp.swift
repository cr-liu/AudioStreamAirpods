//
//  AudioStreamAirpodsApp.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/13.
//

import SwiftUI

@main
struct AudioStreamAirpodsApp: App {
    var backend = Backend()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(backend.sensorVM)
                .environmentObject(backend.robot)
        }
    }
}
