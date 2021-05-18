//
//  ContentView.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/13.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        SensorView(audioIO: AudioIO())
            .environmentObject(HeadmotionViewModel())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
