//
//  SensorView.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/13.
//

import SwiftUI

struct SensorView: View {
    @ObservedObject var audioIO: AudioIO
    @EnvironmentObject var sensorVM: SensorViewModel
    @State private var showingSettingView: Bool = false
    
    var imuAvailable: Bool {
        sensorVM.imuAvailable
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Image(systemName: "airpodspro")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .foregroundColor(imuAvailable ? .accentColor : .gray)
                
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
            
            HStack {
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
                CheckBoxView(checked: $sensorVM.isAntitarget)
                Text("Antitarget")
                Spacer()
                
                Button(action: {
                    sensorVM.isRecording.toggle()
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
        SensorView(audioIO: AudioIO())
            .environmentObject(SensorViewModel())
            .environmentObject(RobotScene())
    }
}
