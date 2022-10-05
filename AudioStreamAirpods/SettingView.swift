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
                }.padding(.trailing)
                Button(action: {
                    sensorVM.channelNumberChanged()
                }) {
                    Image(systemName: sensorVM.isStereo ? "beats.headphones" : "airpod.right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .foregroundColor(.teal)
                }
            }.padding(.bottom, 40)
              
            HStack() {
                Text("Player delay: ")
                    .foregroundColor(.secondary)
                TextField("1", value: $sensorVM.playerDelay, formatter: NumberFormatter())
                    .frame(width: 35)
                    .foregroundColor(Color(UIColor.darkGray))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: sensorVM.playerDelay, perform: { value in
                        sensorVM.playerDelayChanged(to: value)
                    })
                Text(" packets (10ms)")
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: sensorVM.bufCount, total: sensorVM.bufCapacity)
            
            HStack() {
                CheckBoxView(checked: $sensorVM.dropSingleFrame)
                    .onTapGesture {
                        sensorVM.dropPolicyChanged()
                    }.padding()
                Text(" Drop data if delay > ")
                    .foregroundColor(.secondary)
                TextField("50", value: $sensorVM.delayThreshold, formatter: NumberFormatter())
                    .frame(width: 50)
                    .foregroundColor(Color(UIColor.darkGray))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: sensorVM.delayThreshold, perform: { value in
                        sensorVM.delayThresholdChanged(to: value)
                    })
                Text(" ms")
                    .foregroundColor(.secondary)
                
            }.padding(.bottom, 40)
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text("Remote IP: ")
                        .foregroundColor(.secondary)
                    TextField("192.168.2.103", text: $sensorVM.netConf.remoteHost)
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: sensorVM.netConf.remoteHost, perform: { value in
                            sensorVM.remoteHostChanged(to: value)
                        })
                }
                VStack(alignment: .leading) {
                    Text("Port: ")
                        .foregroundColor(.secondary)
                    TextField("12345", value: $sensorVM.netConf.remotePort, formatter: NumberFormatter())
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: sensorVM.netConf.remotePort, perform: { value in
                            sensorVM.remotePortChanged(to: value)
                        })
                }
            }.padding(.bottom, 10)
        
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text("Local IP: ")
                        .foregroundColor(.secondary)
                    TextField("LocalAudioHost", text: $sensorVM.listenHost)
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                }
                VStack(alignment: .leading) {
                    Text("Listen on: ")
                        .foregroundColor(.secondary)
                    TextField("12345", value: $sensorVM.netConf.listenPort, formatter: NumberFormatter())
                        .foregroundColor(Color(UIColor.darkGray))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: sensorVM.netConf.listenPort, perform: { value in
                            sensorVM.sendingPortChanged(to: value)
                        })
                }
            }.padding(.bottom, 10)
                
            Toggle(isOn: $sensorVM.netConf.usingUdp) {
                Text(sensorVM.netConf.usingUdp ? "UDP" : "TCP")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }.onChange(of: sensorVM.netConf.usingUdp) { _ in
                sensorVM.changeSktType()
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
