//
//  Backend.swift
//  AudioStreamAirpods
//
//  Created by liu on 2022/01/19.
//

import Foundation

class Backend {
    var sensorVM = SensorViewModel()
    var robot = RobotScene()
    var bluetoothManager = BluetoothCentralManager()
    
    init() {
        sensorVM.bluetoothLEManager = bluetoothManager
        bluetoothManager.viewModel = sensorVM
    }
}
