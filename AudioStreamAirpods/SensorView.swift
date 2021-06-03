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
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Image(systemName: "airpodspro")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .foregroundColor(sensorVM.imuAvailable ? .accentColor : .gray)
                    .onTapGesture {
                        sensorVM.isUpdatingHeadMotion ? sensorVM.stopMotionUpdate() : sensorVM.startHeadMotionUpdate()
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
                }.sheet(isPresented: $showingSettingView) {
                    SettingView()
                        .environmentObject(sensorVM)
                }
            }.padding()
            
            MessageView().padding()
            
            HStack{
                CheckBoxView(checked: $sensorVM.isAntitarget)
                Text("Antitarget")
            }.onTapGesture {
                sensorVM.makeAntitarget()
            }
            
            HStack {
                Image(systemName: "externaldrive.badge.wifi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(sensorVM.serverStarted ?
                                        .accentColor : .secondary)
                    .onLongPressGesture {
                        sensorVM.serverStarted ?
                            sensorVM.stopTcpServer() :
                            sensorVM.startTcpServer()
                    }
                Spacer()
                Image(systemName: "link")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundColor(sensorVM.isConnected ? .accentColor : .secondary)
                    .onLongPressGesture {
                        sensorVM.isConnected ?
                            sensorVM.closeConnection() :
                            sensorVM.startConnection()
                    }
                Spacer()
                Button(action: {
                    sensorVM.isPlaying.toggle()
                }) {
                    Image(systemName: sensorVM.isPlaying ? "speaker.zzz" : "speaker.wave.2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
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
        }
        
    }
}

struct SensorView_Previews: PreviewProvider {
    static var previews: some View {
        SensorView()
            .environmentObject(SensorViewModel())
            .environmentObject(RobotScene())
    }
}
