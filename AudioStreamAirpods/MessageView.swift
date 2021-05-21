//
//  MessageView.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/20.
//

import SwiftUI

struct MessageView: View {
    @EnvironmentObject var sensorVM: SensorViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(sensorVM.messages, id: \.self) { text in // show received results
                    Text(text)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}


struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        MessageView()
            .environmentObject(SensorViewModel())
    }
}
