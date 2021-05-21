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
            Button(action: {
                sensorVM.repeatMic.toggle()
            }) {
                Image(systemName: "memories")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(sensorVM.repeatMic ? .accentColor : .secondary)
            }
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text("Connect to: ")
                        .foregroundColor(.secondary)
                    TextField("192.168.1.0", text: $sensorVM.connectHost)
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading) {
                    Text("Port: ")
                        .foregroundColor(.secondary)
                    TextField("12345", value: $sensorVM.connectPort, formatter: NumberFormatter())
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                Button(action: {
                    sensorVM.isConnected.toggle()
                }) {
                    Image(systemName: "link")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(sensorVM.isConnected ? .accentColor : .secondary)
                }
            }
        
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text("Server name: ")
                        .foregroundColor(.secondary)
                    TextField("LocalAudioHost", text: $sensorVM.listenHost)
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading) {
                    Text("Listen on: ")
                        .foregroundColor(.secondary)
                    TextField("12345", value: $sensorVM.listenPort, formatter: NumberFormatter())
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                Button(action: {
                    sensorVM.serverStarted.toggle()
                }) {
                    Image(systemName: "externaldrive.badge.wifi")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(sensorVM.serverStarted ? .accentColor : .secondary)
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
