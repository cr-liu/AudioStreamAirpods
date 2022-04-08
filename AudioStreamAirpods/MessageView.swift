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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(sensorVM.messages.indices, id: \.self) { i in
                        Text(sensorVM.messages[i])
                            .foregroundColor(.secondary)
//                            .id(text.self)
                    }.onChange(of: sensorVM.messages.count) { _ in
                        proxy.scrollTo(sensorVM.messages.count-1.self, anchor: .bottom)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        MessageView()
            .environmentObject(SensorViewModel())
    }
}
