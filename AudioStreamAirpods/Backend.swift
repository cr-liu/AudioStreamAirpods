//
//  Backend.swift
//  AudioStreamAirpods
//
//  Created by liu on 2022/01/19.
//

import Foundation
import CoreMotion

class Backend {
    var sensorVM = SensorViewModel()
    var robot = RobotScene()
    var headMotionManager = CMHeadphoneMotionManager()
    var audioIO = AudioIO()
    var tcpServer: AudioTcpServer
    var tcpClient = AudioTcpClient()
    var tcpClientRingBuf: RingBuffer<Int16>
    var bluetoothManager = BluetoothCentralManager()
    
    init() {
        sensorVM.headMotionManager = headMotionManager
        sensorVM.audioIO = audioIO
        
        let imuPtr = sensorVM.imuData4Server.withUnsafeBytes{ $0 }.baseAddress!
        tcpServer = AudioTcpServer(withImu: imuPtr)
        sensorVM.tcpServer = tcpServer
        audioIO.tcpServer = tcpServer
        if let ifAddress = sensorVM.getIPAddress() {
            sensorVM.listenHost = ifAddress
            tcpServer.host = ifAddress
        }
        sensorVM.tcpClient = tcpClient
        
        audioIO.tcpClient = tcpClient
        tcpClientRingBuf = RingBuffer<Int16>(repeating: 0, count: 320 * sensorVM.maxDelay)
        audioIO.tcpSourceRingBuf = tcpClientRingBuf
        tcpClient.setBuffer(tcpClientRingBuf)
        
        sensorVM.bluetoothLEManager = bluetoothManager
        bluetoothManager.viewModel = sensorVM
    }
}
