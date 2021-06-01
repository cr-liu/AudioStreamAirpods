//
//  SettingView.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/20.
//

import SwiftUI

struct SettingView: View {
    @EnvironmentObject var sensorVM: SensorViewModel
    
    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                Text(sensorVM.speakerType)
                    .foregroundColor(.secondary)
                Button(action: {
                    sensorVM.playEcho()
                }) {
                    Image(systemName: "memories")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(sensorVM.isPlayingEcho ? .accentColor : .secondary)
                }
            }.padding(.bottom, 40)
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text("Connect to: ")
                        .foregroundColor(.secondary)
                    TextField("192.168.1.0", text: $sensorVM.connectHost)
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: sensorVM.connectHost, perform: { value in
                            sensorVM.connectHostChanged(to: value)
                        })
                }
                VStack(alignment: .leading) {
                    Text("Port: ")
                        .foregroundColor(.secondary)
                    TextField("12345", value: $sensorVM.connectPort, formatter: NumberFormatter())
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: sensorVM.connectPort, perform: { value in
                            sensorVM.connectPortChanged(to: value)
                        })
                }
            }.padding(.bottom, 30)
        
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text("Server name: ")
                        .foregroundColor(.secondary)
                    TextField("LocalAudioHost", text: $sensorVM.listenHost)
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                }
                VStack(alignment: .leading) {
                    Text("Listen on: ")
                        .foregroundColor(.secondary)
                    TextField("12345", value: $sensorVM.listenPort, formatter: NumberFormatter())
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: sensorVM.listenPort, perform: { value in
                            sensorVM.listenPortChanged(to: value)
                        })
                }

            }
        }.padding()
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
            .environmentObject(SensorViewModel())
    }
}
