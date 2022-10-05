//
//  ViewModel.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/17.
//

import Foundation
import CoreMotion
import AVFoundation
import CoreBluetooth
import NIO

class SensorViewModel: ObservableObject {
    @Published var messages: [String] = []
    
    var maxDelay = 100
    @Published var playerDelay: Int = 1
    @Published var isPlayingEcho: Bool = false
    @Published var isPlaying : Bool = false
    @Published var isRecording: Bool = false
    @Published var speakerType: String = ""
    @Published var bufCapacity: Float32 = 320 * 100 // change with maxDelay
    @Published var bufCount: Float32 = 0
    @Published var delayThreshold: Int = 50
    @Published var dropSingleFrame: Bool = false
    weak var audioIO: AudioIO?
    
    @Published var headPitch: Float = 0
    @Published var headYaw: Float = 0
    @Published var headRoll: Float = 0
    @Published var imuAvailable: Bool = false
    @Published var isUpdatingHeadMotion = false
    weak var headMotionManager: CMHeadphoneMotionManager?
    
//    @Published var iphonePitch: Float = 0
//    @Published var iphoneYaw: Float = 0
//    @Published var iphoneRoll: Float = 0
//    @Published var iphoneAccX: Float = 0
//    @Published var iphoneAccY: Float = 0
//    @Published var iphoneAccZ: Float = 0
//    private var isUpdatingMotion: Bool = false
//    private var motionManager = CMMotionManager()
    
    @Published var netConf: NetConfig = NetConfig(
        usingUDP: false,
        remotePort: 1234,
        listenPort: 12345,
        remoteHost: "192.168.2.101"
    )
    @Published var listenHost: String = "LocalHost"
    @Published var isSending: Bool = false
    @Published var isAntitarget: Bool = false
    weak var tcpServer: AudioTcpServer?
    weak var udpClient: AudioUdpClient?
    var imuData4Sender = Array<Float32>(repeating: -10000, count: 16)
    //    var phoneRoll: Float32 = -10000
    //    var phonePitch: Float32 = -10000
    //    var phoneYaw: Float32 = -10000
    //    var phoneAccX: Float32 = -10000
    //    var phoneAccY: Float32 = -10000
    //    var phoneAccZ: Float32 = -10000
    //    var phoneCompass: Float32 = -10000
    //    var phoneGpsN: Float32 = -10000
    //    var phoneGpsE: Float32 = -10000
    //    var calib: Float32 = -10000
    //    var headRoll: Float32 = -10000
    //    var headPitch: Float32 = -10000
    //    var headYaw: Float32 = -10000
    //    var headAccX: Float32 = -10000
    //    var headAccY: Float32 = -10000
    //    var headAccZ: Float32 = -10000

    @Published var isReceiving: Bool = false
    @Published var isStereo: Bool = true
    weak var tcpClient: AudioTcpClient?
    weak var udpServer: AudioUdpServer?
    
    @Published var bluetoothPeripherals = Set<CBPeripheral>()
    weak var bluetoothLEManager: BluetoothCentralManager?
    
    init() {
        registerForNotifications()
        collectMessage()
    }
    
    deinit {
        if isSending { stopSender() }
        if isRecording { stopAudioSess() }
    }
    
    func registerForNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] (notification) in
            guard let weakself = self else {
                return
            }
            weakself.stopAudioSess()
            weakself.checkIMU()
        }
    }
    
    func loadConfig() {
        ConfigStore.load(netConf: self.netConf) { result in
            switch result {
            case .failure(let error):
                fatalError(error.localizedDescription)
            case .success(let conf):
                self.netConf = conf
            }
        }
    }
    
    func saveConfig() {
        ConfigStore.save(netConf: self.netConf) { result in
            if case .failure(let error) = result {
                fatalError(error.localizedDescription)
            }
        }
    }

    // Message
    func addMessage(_ msg: String) {
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "HH:mm:ss.SSS"
//        self.messages.append(msg + " -- " + dateFormatter.string(from: Date()))
        self.messages.append(msg)
    }
    
    func collectMessage() {
        if audioIO != nil && !(audioIO!.messages.isEmpty) {
            for msg in audioIO!.messages {
                addMessage(msg)
            }
            audioIO!.messages.removeAll()
        }
        if tcpServer != nil {
            if let ifAddress = getIPAddress() {
                listenHost = ifAddress
                tcpServer!.host = ifAddress
            }
        }
        if bluetoothLEManager != nil && !(bluetoothLEManager!.messages.isEmpty) {
            for msg in bluetoothLEManager!.messages {
                addMessage(msg)
            }
            bluetoothLEManager!.messages.removeAll()
        }
        if audioIO != nil {
            bufCount = Float32(audioIO!.recvRingBuf!.count)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: collectMessage)
    }
    
    
    // Audio input/output
    func startAudioSess() {
        if isRecording {
            return
        }
        guard let _ = try? audioIO!.startAudioSess() else {
            addMessage("Failed start audio session!")
            return
        }
        isRecording = true
        addMessage("Audio session started.")
    }
    
    func pauseAudioSess() {
        audioIO!.pauseAudioSess()
        isRecording = false
        addMessage("Audio session paused.")
    }
    
    func stopAudioSess() {
        if audioIO!.isStopped() {
            return
        }
        audioIO!.stopAudioSess()
        isRecording = false
        addMessage("Audio session stopped.")
    }
    
    func playTcpSource() {
        isPlaying.toggle()
        audioIO!.playRemoteSource(isPlaying)
    }
    
    func playEcho() {
        isPlayingEcho.toggle()
        audioIO!.playEcho(isPlayingEcho)
    }
    
    func playerDelayChanged(to newDelay: Int) {
        if (newDelay == audioIO!.playerDelay) {
            return
        }
        if (newDelay * 10 > delayThreshold) {
            delayThresholdChanged(to: newDelay * 10)
        }
        if (newDelay < 1) {
            audioIO!.setPlayerDelay(to: 1)
        } else if (newDelay > maxDelay) {
            audioIO!.setPlayerDelay(to: maxDelay)
        } else {
            audioIO!.setPlayerDelay(to: newDelay)
        }
    }
    
    func delayThresholdChanged(to newThreshold: Int) {
        delayThreshold = newThreshold
        audioIO?.delayThreshold = newThreshold / 10
    }
    
    func dropPolicyChanged() {
        dropSingleFrame.toggle()
        audioIO?.dropOne = dropSingleFrame
    }

    // Headset IMU
    func checkIMU() {
        if audioIO == nil || headMotionManager == nil {
            return
        }
        speakerType = audioIO!.outputDeviceType()
        imuAvailable = headMotionManager!.isDeviceMotionAvailable && speakerType == "Bluetooth A2DP"
    }
    
    func startHeadMotionUpdate() {
        bluetoothLEManager?.cleanup()
        checkIMU()
        guard imuAvailable, !isUpdatingHeadMotion else {
            return
        }

        addMessage("Start airpods Motion Update")
        isUpdatingHeadMotion = true
        headMotionManager!.startDeviceMotionUpdates(to: OperationQueue.current!) { [weak self] (motion, error) in
            guard let weakself = self else {
                return
            }
            if let error = error {
                DispatchQueue.main.async {
                    weakself.addMessage("\(error)")
                }
            }
            if let motion = motion {
                weakself.updateMotionData(motion)
            }
        }
    }
    
    func stopMotionUpdate() {
        guard headMotionManager!.isDeviceMotionAvailable,
              isUpdatingHeadMotion else {
            return
        }
        addMessage("Stop airpods Motion Update")
        isUpdatingHeadMotion = false
        headMotionManager!.stopDeviceMotionUpdates()
    }
    
    func updateMotionData(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude
        let acceleration = motion.userAcceleration
        DispatchQueue.main.async {
            (self.headPitch, self.headYaw, self.headRoll)
            = (-Float(attitude.pitch), Float(attitude.yaw), Float(-attitude.roll))
            (self.imuData4Sender[10], self.imuData4Sender[11], self.imuData4Sender[12])
            = (Float32(attitude.roll), Float32(attitude.pitch), Float32(attitude.yaw))
            (self.imuData4Sender[13], self.imuData4Sender[14], self.imuData4Sender[15])
            = (Float32(acceleration.x), Float32(acceleration.y), Float32(acceleration.z))
        }
    }
    

    // Phone IMU
    
    // Socket type
    func changeSktType() {
        audioIO?.usingUdp = netConf.usingUdp
        stopSender()
        stopReceiver()
    }

    
    func getIPAddress() -> String? {
        var address: String?
        
        do {
            let matchingInterfaces = try System.enumerateDevices().filter {
                // find an IPv4 interface named en0 that has a broadcast address.
                // wifi = ["en0"]
                // wired = ["en2", "en3", "en4"]
                // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]
                $0.name == "en0" && $0.broadcastAddress != nil
            }
            address = matchingInterfaces.first?.address?.ipAddress
        } catch {
            self.addMessage("No suitable net interface found")
        }

        return address
    }
    
    // Socket sender
    func sendingPortChanged(to port: Int) {
        tcpServer?.port = port
        udpClient?.port = port
        if isSending {
            stopSender()
        }
    }
    
    func startSender() {
        if netConf.usingUdp {
            udpClient?.asyncRun()
        } else {
            tcpServer?.asyncRun()
        }
    }
    
    func stopSender() {
        udpClient?.shutdown()
        tcpServer?.shutdown()
    }
    
    func makeAntitarget() {
        isAntitarget.toggle()
        tcpServer?.h80D10ms16kHandler.isAntitarget = isAntitarget
        udpClient?.h80D10ms16kHandler.isAntitarget = isAntitarget
    }
    

    // Socket receiver
    func remoteHostChanged(to host: String) {
        tcpClient?.host = host
//        udpServer?.host = host
        if isReceiving {
            stopReceiver()
        }
    }
    
    func remotePortChanged(to port: Int) {
        tcpClient?.port = port
        udpServer?.port = port
        if isReceiving {
            stopReceiver()
        }
    }
    
    func startReceiver() {
        if netConf.usingUdp {
            udpServer?.AsyncStart()
        } else {
            tcpClient?.AsyncStart()
        }
        startAudioSess()
    }
    
    func stopReceiver() {
        udpServer?.stop()
        tcpClient?.stop()
    }
    
    func channelNumberChanged() {
        isStereo.toggle()
        tcpClient?.h80D10ms16kHandler.audioChannels = isStereo ? 2 : 1
        udpServer?.h80D10ms16kHandler.audioChannels = isStereo ? 2 : 1
        addMessage(isStereo ? "Expecting 2ch sound" : "Expecting 1ch sound")
    }
    
    // Bluetooth LE IMU
    func scanBluetooth() {
        let scanWorkItem = DispatchWorkItem {
            self.bluetoothLEManager!.retrievePeripheral()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            scanWorkItem.perform()
        }
        scanWorkItem.notify(queue: DispatchQueue.main) {
            self.bluetoothPeripherals = self.bluetoothLEManager!.peripherals
        }
    }
    
    func connectBluetooth(_ idx: Int) {
        bluetoothLEManager!.asyncConnectPeripheral(idx)
    }
}

