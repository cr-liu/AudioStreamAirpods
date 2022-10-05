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
    var tcpClient: AudioTcpClient
    var udpClient: AudioUdpClient
    var udpServer: AudioUdpServer
    var netRecvRingBuf: RingBuffer<Int16>
    var bluetoothManager = BluetoothCentralManager()
    
    init() {
        sensorVM.headMotionManager = headMotionManager
        sensorVM.audioIO = audioIO
        audioIO.viewModel = sensorVM
        audioIO.usingUdp = sensorVM.netConf.usingUdp
        
        let imuPtr = sensorVM.imuData4Sender.withUnsafeBytes{ $0 }.baseAddress!
        
        // Tcp sender
        tcpServer = AudioTcpServer(withImu: imuPtr)
        sensorVM.tcpServer = tcpServer
        tcpServer.viewModel = sensorVM
        tcpServer.h80D10ms16kHandler.viewModel = sensorVM
        audioIO.tcpServer = tcpServer
        tcpServer.port = sensorVM.netConf.listenPort
        if let ifAddress = sensorVM.getIPAddress() {
            sensorVM.listenHost = ifAddress
            tcpServer.host = ifAddress
        }
        
        // Udp sender
        udpClient = AudioUdpClient(withImu: imuPtr)
        sensorVM.udpClient = udpClient
        udpClient.viewModel = sensorVM
        audioIO.udpClient = udpClient
        
        
        
        // Tcp receiver
        tcpClient = AudioTcpClient()
        sensorVM.tcpClient = tcpClient
        tcpClient.viewModel = sensorVM
        tcpClient.h80D10ms16kHandler.viewModel = sensorVM
        tcpClient.host = sensorVM.netConf.remoteHost
        tcpClient.port = sensorVM.netConf.remotePort
        
        // Udp receiver
        udpServer = AudioUdpServer()
        sensorVM.udpServer = udpServer
        udpServer.viewModel = sensorVM
        
        netRecvRingBuf = RingBuffer<Int16>(repeating: 0, count: 320 * sensorVM.maxDelay)
        audioIO.recvRingBuf = netRecvRingBuf
        tcpClient.setBuffer(netRecvRingBuf)
        udpServer.setBuffer(netRecvRingBuf)
        
        sensorVM.bluetoothLEManager = bluetoothManager
        bluetoothManager.viewModel = sensorVM
    }
}
