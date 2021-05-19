//
//  SensorView.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/13.
//

import SwiftUI

struct SensorView: View {
    @ObservedObject var audioIO: AudioIO
    @EnvironmentObject var headmotionVM: HeadmotionViewModel
    
    var imuAvailable: Bool {
        headmotionVM.imuAvailable
    }
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "airpodspro")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .foregroundColor(imuAvailable ? .accentColor : .gray)
                    
                Spacer()
                
                Button(action: /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Action@*/{}/*@END_MENU_TOKEN@*/) {
                    Image(systemName: "ellipsis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35)
                        .foregroundColor(.gray)
                }
            }.padding()
            
            HeadMotionSceneView()
            
            Spacer()
            
            if audioIO.recording == false {
                Button(action: {print("Start recording")}) {
                    Image(systemName: "circle.fill")
                        .resizable()
//                        .aspectRatio(contentMode: .fill)
                        .scaledToFit()
                        .frame(width: 70)
                        .clipped()
                        .foregroundColor(.red)
                        .padding(.bottom, 40)
                }
            } else {
                Button(action: {print("Stop recording)")}) {
                    Image(systemName: "stop.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .foregroundColor(.red)
                        .padding(.bottom, 40)
                }
            }
        }
        
    }
}

struct SensorView_Previews: PreviewProvider {
    static var previews: some View {
        SensorView(audioIO: AudioIO())
            .environmentObject(HeadmotionViewModel())
    }
}
