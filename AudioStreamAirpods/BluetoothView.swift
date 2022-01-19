//
//  BluetoothView.swift
//  AudioStreamAirpods
//
//  Created by liu on 2022/01/17.
//

import SwiftUI

struct BluetoothView: View {
    @EnvironmentObject var sensorVM: SensorViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Spacer()
                Image(systemName: "airpodspro")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25)
                    .foregroundColor(sensorVM.imuAvailable ? .accentColor : .gray)
                    .onTapGesture {
                        sensorVM.isUpdatingHeadMotion ? sensorVM.stopMotionUpdate() : sensorVM.startHeadMotionUpdate()
                        presentationMode.wrappedValue.dismiss()
                    }
            }.padding(20)
            HStack {
                Text("Bluetooth LE Devices")
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
                    .foregroundColor(.teal)
                    .onTapGesture {
                        sensorVM.scanBluetooth()
                    }
            }.padding(20)
            Spacer()
            ForEach(0..<sensorVM.bluetoothPeripherals.count, id: \.self) {idx in
                Text(sensorVM.bluetoothPeripherals[sensorVM.bluetoothPeripherals.index(sensorVM.bluetoothPeripherals.startIndex, offsetBy: idx)].name!)
                    .foregroundColor(.secondary)
                    .padding()
                    .onTapGesture {
                        sensorVM.connectBluetooth(idx)
                        presentationMode.wrappedValue.dismiss()
                    }
            }
            Spacer()
        }.padding()
    }
}

struct BluetoothView_Previews: PreviewProvider {
    static var previews: some View {
        BluetoothView()
            .environmentObject(SensorViewModel())
    }
}
