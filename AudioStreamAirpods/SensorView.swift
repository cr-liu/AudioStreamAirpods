//
//  SensorView.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/13.
//

import SwiftUI

struct SensorView: View {
    @EnvironmentObject var sensorVM: SensorViewModel
    @State private var showingSettingView: Bool = false
    @State private var showingBluetoothView: Bool = false
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Button(action: {
                    self.showingBluetoothView.toggle()
                }) {
                    Image(systemName: "airpodspro")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                        .foregroundColor(sensorVM.imuAvailable ? .accentColor : .gray)
                }.sheet(isPresented: $showingBluetoothView) {
                    BluetoothView()
                        .onAppear(perform: { sensorVM.scanBluetooth()
                        })
                        .environmentObject(sensorVM)
                }
                
                MotionSceneView()
                    .offset(y: -300.0)
                    .padding(.bottom, -300)
                
                Button(action: {
                    self.showingSettingView.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30)
                        .foregroundColor(.gray)
                }.sheet(isPresented: $showingSettingView, onDismiss: {
                    sensorVM.saveConfig()
                }) {
                    SettingView()
                        .environmentObject(sensorVM)
                }
            }.padding()
            
            MessageView().padding()
            
            HStack{
                CheckBoxView(checked: $sensorVM.isAntitarget)
                Text("Antitarget")
                    .foregroundColor(.secondary)
            }.onTapGesture {
                sensorVM.makeAntitarget()
            }
            
            HStack {
                Image(systemName: "icloud.and.arrow.up")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundColor(sensorVM.isSending ?
                                        .accentColor : .secondary)
                    .onLongPressGesture {
                        sensorVM.isSending ?
                            sensorVM.stopSender() :
                            sensorVM.startSender()
                    }
                Spacer()
                Image(systemName: "iphone.and.arrow.forward")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundColor(sensorVM.isReceiving ? .accentColor : .secondary)
                    .onLongPressGesture {
                        sensorVM.isReceiving ?
                            sensorVM.stopReceiver() :
                            sensorVM.startReceiver()
                    }
                Spacer()
                Button(action: {
                    sensorVM.playTcpSource()
                }) {
                    Image(systemName: sensorVM.isPlaying ? "speaker.zzz" : "speaker.wave.2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(sensorVM.isPlaying ? .mint : .gray)
                }
                Spacer()
                Button(action: {
                    sensorVM.isRecording ? sensorVM.pauseAudioSess() : sensorVM.startAudioSess()
                }) {
                    Image(systemName: sensorVM.isRecording ? "mic.slash" : "mic")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.red)
                }
            }.padding(.bottom, 40).padding(.leading, 50).padding(.trailing, 50)
        }.onAppear { sensorVM.loadConfig() }
    }
}

struct SensorView_Previews: PreviewProvider {
    static var previews: some View {
        SensorView()
            .environmentObject(SensorViewModel())
            .environmentObject(RobotScene())
    }
}
